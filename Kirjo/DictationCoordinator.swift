import AppKit
import Foundation
import NotikaCore
import NotikaMacOS
import NotikaPostProcessing
import NotikaTranscription
import NotikaDictionary
import NotikaWhisper
import os

/// Orchestriert den Diktat-Flow. Phase 1a Schritt 4:
/// Hotkey → Aufnahme → (stop) → Transkription → Log.
/// Post-Processing und Text-Insertion folgen in Schritt 5 und 6.
@MainActor
final class DictationCoordinator {
    private let logger = Logger(subsystem: "com.notika.mac", category: "Coordinator")
    private let hotkeyManager = HotkeyManager()
    private let recorder = AudioRecorder()
    private let overlay = OverlayController.shared
    private var transcriptionEngine: TranscriptionEngine
    private let settings = SettingsStore()
    private let textInserter = TextInserter()
    private let costStore = CostStore()
    private let historyStore = HistoryStore()
    private let whisperModelStore = WhisperModelStore()
    private let dictionaryStore = DictionaryStore()

    private var hotkeyTask: Task<Void, Never>?
    private var levelsTask: Task<Void, Never>?
    private var pipelineTask: Task<Void, Never>?
    /// Zustand, um im Toggle-Modus zu wissen, ob wir gerade aufnehmen.
    private var activeMode: DictationMode?

    /// Cache für die STT-Engine, damit WhisperKit nicht bei jedem Diktat
    /// das Modell neu laden muss (spart 2-5s pro Pipeline).
    private var cachedEngineChoice: STTEngineChoice?
    private var cachedEngine: TranscriptionEngine?

    init() {
        self.transcriptionEngine = TranscriptionEngineFactory.makeEngine(.appleSpeechAnalyzer)
    }

    /// Liefert die zur aktuellen Settings-Wahl passende Post-Processing-Engine.
    /// `nil` = kein LLM, Rohtranskript unverändert zurückgeben.
    private func makePostProcessingEngine(for mode: DictationMode) -> PostProcessingEngine? {
        let choice = settings.effectiveChoice(for: mode)
        return PostProcessingEngineFactory.makeEngine(for: choice)
    }

    /// Wählt die TranscriptionEngine für das nächste Diktat basierend auf den Settings.
    /// Bei `.whisper(modelID)` mit fehlendem Modell: Fallback auf Apple + Pill-Hinweis.
    private func resolveTranscriptionEngine() -> TranscriptionEngine {
        let choice = settings.sttEngineChoice
        if let cachedChoice = cachedEngineChoice,
           let cached = cachedEngine,
           cachedChoice == choice {
            return cached
        }
        switch choice {
        case .apple:
            let engine = TranscriptionEngineFactory.makeEngine(.appleSpeechAnalyzer)
            cachedEngineChoice = .apple
            cachedEngine = engine
            logger.info("STT-Engine erzeugt (cached): Apple")
            return engine
        case .whisper(let modelID):
            if whisperModelStore.installedModels().contains(modelID) {
                let engine = WhisperKitEngine(modelID: modelID, modelStore: whisperModelStore)
                cachedEngineChoice = choice
                cachedEngine = engine
                logger.info("STT-Engine erzeugt (cached): Whisper \(modelID.rawValue, privacy: .public)")
                return engine
            }
            logger.warning("Whisper-Modell \(modelID.rawValue, privacy: .public) nicht installiert — Fallback auf Apple")
            // Fallback-Engine bewusst NICHT cachen: sobald das Modell
            // installiert wird, soll der nächste Diktatversuch Whisper nutzen.
            return TranscriptionEngineFactory.makeEngine(.appleSpeechAnalyzer)
        }
    }

    func start() {
        hotkeyManager.start()
        refreshHotkeyConfigs()
        hotkeyTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in self.hotkeyManager.events {
                self.handle(event)
            }
        }
        // UI-Änderungen im Kurzbefehle-Tab triggern Reconfigure
        NotificationCenter.default.addObserver(
            forName: .notikaHotkeyConfigChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshHotkeyConfigs() }
        }
        logger.info("DictationCoordinator gestartet")
    }

    /// Wärmt die aktuell konfigurierte STT-Engine vor, damit das erste
    /// Diktat nach App-Start keinen Cold-Start-Delay hat.
    /// Safe, um im Hintergrund aufgerufen zu werden (Task.detached).
    func preWarm() async {
        let engine = resolveTranscriptionEngine()
        let started = Date()
        await engine.preWarm()
        let elapsed = Date().timeIntervalSince(started)
        logger.info("⏱️ Pre-Warm: \(String(format: "%.2f", elapsed))s")
    }

    /// Liest die aktuellen Hotkey-Configs aus dem SettingsStore und wendet
    /// sie auf den HotkeyManager an. Wird beim Start + bei UI-Änderungen aufgerufen.
    func refreshHotkeyConfigs() {
        var configs: [DictationMode: ModeHotkeyConfig] = [:]
        for mode in DictationMode.allCases {
            configs[mode] = settings.hotkeyConfig(for: mode)
        }
        hotkeyManager.applyModifierConfigs(configs)
        logger.info("Hotkey-Configs aktualisiert (\(configs.count, privacy: .public) Modi)")
    }

    func stop() {
        hotkeyTask?.cancel()
        levelsTask?.cancel()
        pipelineTask?.cancel()
        hotkeyManager.stop()
        NotificationCenter.default.removeObserver(self, name: .notikaHotkeyConfigChanged, object: nil)
    }

    // MARK: - Event-Handling

    private func handle(_ event: HotkeyEvent) {
        let mode: DictationMode
        switch event {
        case .pressed(let m), .released(let m): mode = m
        }
        let triggerMode = settings.hotkeyConfig(for: mode).triggerMode
        switch triggerMode {
        case .pushToTalk:
            handlePushToTalk(event)
        case .toggle:
            handleToggle(event)
        }
    }

    private func handlePushToTalk(_ event: HotkeyEvent) {
        switch event {
        case .pressed(let mode):
            beginRecording(mode: mode)
        case .released:
            finishRecording()
        }
    }

    private func handleToggle(_ event: HotkeyEvent) {
        guard case .pressed(let mode) = event else { return }
        if activeMode == nil {
            beginRecording(mode: mode)
        } else {
            finishRecording()
        }
    }

    // MARK: - Recording

    private func beginRecording(mode: DictationMode) {
        maybeShowFirstUseHint(mode: mode)
        guard activeMode == nil else { return }
        activeMode = mode
        overlay.updateState(.recording(mode: mode))

        do {
            try recorder.start()
        } catch {
            logger.error("Recording-Start fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            overlay.updateState(.error(message: "Mikrofon nicht verfügbar"))
            activeMode = nil
            return
        }

        let stream = recorder.levelStream()
        levelsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await level in stream {
                self.overlay.pushAudioLevel(level)
            }
        }
    }

    private func finishRecording() {
        guard let mode = activeMode else { return }
        levelsTask?.cancel()
        levelsTask = nil

        let url = recorder.stop()
        activeMode = nil

        guard let url else {
            overlay.updateState(.idle)
            return
        }

        runPipeline(mode: mode, audioURL: url)
    }

    // MARK: - Pipeline (Transkription)

    private func runPipeline(mode: DictationMode, audioURL: URL) {
        pipelineTask?.cancel()
        pipelineTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let tStart = Date()
            self.overlay.updateState(.transcribing(mode: mode))

            do {
                let engine = self.resolveTranscriptionEngine()
                let hints = self.dictionaryStore.hintsForLanguage(.german)
                let transcript: Transcript
                do {
                    transcript = try await engine.transcribe(
                        audio: .file(audioURL),
                        language: .german,
                        hints: hints
                    )
                } catch let err as WhisperError {
                    self.logger.warning("Whisper-Fehler: \(String(describing: err), privacy: .public) — Fallback auf Apple")
                    self.overlay.updateState(.error(message: err.userFacingMessage))
                    try? await Task.sleep(for: .seconds(2))
                    self.overlay.updateState(.transcribing(mode: mode))
                    let appleEngine = TranscriptionEngineFactory.makeEngine(.appleSpeechAnalyzer)
                    transcript = try await appleEngine.transcribe(
                        audio: .file(audioURL),
                        language: .german,
                        hints: hints
                    )
                }

                let tSTT = Date()
                let sttSec = String(format: "%.2f", tSTT.timeIntervalSince(tStart))
                self.logger.notice("⏱️ STT: \(sttSec, privacy: .public)s")

                if transcript.text.isEmpty {
                    self.logger.warning("Leeres Transkript für \(audioURL.path, privacy: .public)")
                    self.overlay.updateState(.error(message: "Nichts verstanden"))
                } else {
                    self.logger.info("Transkript roh: \(transcript.text, privacy: .public)")

                    let processed: String
                    var engineResult: ProcessedText?
                    if let engine = self.makePostProcessingEngine(for: mode) {
                        self.overlay.updateState(.processing(mode: mode))
                        do {
                            let result = try await engine.process(
                                transcript: transcript.text,
                                mode: mode,
                                language: .german
                            )
                            processed = result.text.isEmpty ? transcript.text : result.text
                            engineResult = result
                            self.costStore.record(costUSD: result.costUSD)
                            self.logger.info("Transkript final (LLM): \(processed, privacy: .public)")
                        } catch let err as LLMError {
                            self.logger.warning("LLM-Fehler: \(String(describing: err), privacy: .public) — Rohtext-Fallback")
                            processed = transcript.text
                            self.overlay.updateState(.error(message: err.userFacingMessage))
                            try? await Task.sleep(for: .seconds(2))
                        }
                    } else {
                        processed = transcript.text
                        self.logger.info("Ohne LLM — Rohtranskript durchgereicht")
                    }

                    let tLLM = Date()
                    let llmSec = String(format: "%.2f", tLLM.timeIntervalSince(tSTT))
                    self.logger.notice("⏱️ LLM: \(llmSec, privacy: .public)s")

                    self.overlay.updateState(.inserting(mode: mode))
                    let result = await self.textInserter.insert(processed)
                    let tInsert = Date()
                    let insertSec = String(format: "%.2f", tInsert.timeIntervalSince(tLLM))
                    let totalSec = String(format: "%.2f", tInsert.timeIntervalSince(tStart))
                    self.logger.notice("⏱️ Insert: \(insertSec, privacy: .public)s · Total: \(totalSec, privacy: .public)s")
                    switch result {
                    case .inserted:
                        if !processed.isEmpty {
                            let providerID: PostProcessingEngineID = engineResult?.provider ?? .none
                            let modelID = engineResult?.model
                            let cost = engineResult?.costUSD
                            self.historyStore.append(
                                text: processed,
                                mode: mode,
                                provider: providerID,
                                modelID: modelID,
                                costUSD: cost
                            )
                        }
                        try? await Task.sleep(for: .milliseconds(300))
                    case .clipboardOnly:
                        self.logger.warning("Auto-Insert nicht möglich — Text nur in Zwischenablage.")
                        self.overlay.updateState(.error(message: "In Zwischenablage · Bedienungshilfen aktivieren!"))
                        try? await Task.sleep(for: .seconds(3))
                        AppDelegate.shared?.showOnboarding()
                    }
                }
            } catch {
                self.logger.error("Transkription fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
                self.overlay.updateState(.error(message: error.localizedDescription))
                try? await Task.sleep(for: .seconds(2))
            }

            self.overlay.updateState(.idle)
            // Temp-Datei löschen
            try? FileManager.default.removeItem(at: audioURL)
        }
    }

    // MARK: - First-Use-Hint

    /// Zeigt einmalig den First-Use-Hint, wenn der Onboarding-Step geskippt wurde
    /// und der User Mode 2 oder 3 nutzt.
    private func maybeShowFirstUseHint(mode: DictationMode) {
        let stepCompleted = UserDefaults.standard.bool(forKey: "notika.onboarding.llmStepCompleted")
        let alreadyShown  = UserDefaults.standard.bool(forKey: "notika.hint.llmShown")
        guard !stepCompleted, !alreadyShown, mode != .literal else { return }
        UserDefaults.standard.set(true, forKey: "notika.hint.llmShown")
        AppDelegate.shared?.showLLMHintSheet()
    }
}

import AppKit
import Foundation
import NotikaCore
import NotikaMacOS
import NotikaPostProcessing
import NotikaTranscription
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

    private var hotkeyTask: Task<Void, Never>?
    private var levelsTask: Task<Void, Never>?
    private var pipelineTask: Task<Void, Never>?
    private var triggerMode: HotkeyManager.TriggerMode = .pushToTalk

    /// Zustand, um im Toggle-Modus zu wissen, ob wir gerade aufnehmen.
    private var activeMode: DictationMode?

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
        switch settings.sttEngineChoice {
        case .apple:
            return TranscriptionEngineFactory.makeEngine(.appleSpeechAnalyzer)
        case .whisper(let modelID):
            if whisperModelStore.installedModels().contains(modelID) {
                return WhisperKitEngine(modelID: modelID, modelStore: whisperModelStore)
            }
            logger.warning("Whisper-Modell \(modelID.rawValue, privacy: .public) nicht installiert — Fallback auf Apple")
            return TranscriptionEngineFactory.makeEngine(.appleSpeechAnalyzer)
        }
    }

    func start() {
        hotkeyManager.start()
        hotkeyTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in self.hotkeyManager.events {
                self.handle(event)
            }
        }
        logger.info("DictationCoordinator gestartet")
    }

    func stop() {
        hotkeyTask?.cancel()
        levelsTask?.cancel()
        pipelineTask?.cancel()
        hotkeyManager.stop()
    }

    // MARK: - Event-Handling

    private func handle(_ event: HotkeyEvent) {
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

            self.overlay.updateState(.transcribing(mode: mode))

            do {
                let engine = self.resolveTranscriptionEngine()
                let transcript: Transcript
                do {
                    transcript = try await engine.transcribe(
                        audio: .file(audioURL),
                        language: .german,
                        hints: []
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
                        hints: []
                    )
                }

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
                            if let model = result.model,
                               let tIn = result.tokensIn,
                               let tOut = result.tokensOut {
                                self.costStore.record(modelID: model, tokensIn: tIn, tokensOut: tOut)
                            }
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

                    self.overlay.updateState(.inserting(mode: mode))
                    let result = await self.textInserter.insert(processed)
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

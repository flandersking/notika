import AVFoundation
import CoreMedia
import Foundation
import KirjoCore
import Speech
import os

/// Transkribiert Audio-Dateien mit dem nativen macOS-26 Speech-Framework.
/// Läuft komplett on-device, benötigt die Speech-Recognition-Permission und
/// eine einmalig heruntergeladene Sprach-Asset-Datei.
public final class AppleSpeechAnalyzerEngine: TranscriptionEngine {

    public let id: TranscriptionEngineID = .appleSpeechAnalyzer
    public let supportsStreaming = false

    private let logger = Logger(subsystem: "com.notika.mac", category: "Transcription.Apple")

    public init() {}

    public func transcribe(
        audio: AudioSource,
        language: Language,
        hints: [String]
    ) async throws -> Transcript {
        let locale = Locale(identifier: language.localeIdentifier)

        // SpeechTranscriber mit `.transcription` passt für vorab aufgezeichnete
        // Audio-Dateien (unser Use-Case).
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)

        try await ensureAssetsInstalled(for: transcriber)

        let audioFile: AVAudioFile
        switch audio {
        case .file(let url):
            audioFile = try AVAudioFile(forReading: url)
            logger.info("Audio geladen: \(url.lastPathComponent, privacy: .public) (\(audioFile.length) Frames, \(audioFile.fileFormat.sampleRate, format: .fixed) Hz)")
        case .samples:
            throw KirjoError.transcriptionFailed(
                "AppleSpeechAnalyzer benötigt aktuell eine Datei."
            )
        }

        // Wichtig: Erst den Results-Collector starten, DANN den Analyzer —
        // sonst rauscht die Analyse durch, bevor irgendjemand zuhört.
        async let collected: (String, [Transcript.Segment]) = {
            var text = ""
            var segments: [Transcript.Segment] = []
            var count = 0
            for try await result in transcriber.results {
                count += 1
                let plain = String(result.text.characters)
                logger.debug("Result #\(count) range=\(CMTimeGetSeconds(result.range.start))..\(CMTimeGetSeconds(result.range.end)) »\(plain, privacy: .public)«")
                text += plain
                let startSec = CMTimeGetSeconds(result.range.start)
                let endSec = CMTimeGetSeconds(result.range.end)
                segments.append(.init(text: plain, start: startSec, end: endSec))
            }
            logger.info("Collector fertig: \(count) Results, \(text.count) chars")
            return (text, segments)
        }()

        // Dem Collector einen Moment Zeit geben, sich beim AsyncSequence zu registrieren.
        try? await Task.sleep(for: .milliseconds(50))

        logger.info("Analyse startet …")
        let analyzer = try await SpeechAnalyzer(
            inputAudioFile: audioFile,
            modules: [transcriber],
            finishAfterFile: true
        )
        logger.info("SpeechAnalyzer initialisiert — Analyse läuft")

        // Warte auf Collector — der endet, wenn der Transcriber seinen Stream
        // nach `finishAfterFile: true` schließt.
        let (text, segments) = try await collected
        logger.info("Collector zurück: \(text.count) chars")

        _ = analyzer  // keep alive

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("Transcript (\(trimmed.count) chars): »\(trimmed, privacy: .public)«")

        return Transcript(
            text: trimmed,
            segments: segments,
            detectedLanguage: language
        )
    }

    // MARK: - Asset-Management

    private func ensureAssetsInstalled(for module: some LocaleDependentSpeechModule) async throws {
        let status = await AssetInventory.status(forModules: [module])
        logger.info("Asset status vor: \(String(describing: status), privacy: .public)")

        switch status {
        case .installed:
            return
        case .unsupported:
            throw KirjoError.transcriptionFailed(
                "Diese Sprache wird von Apple SpeechAnalyzer nicht unterstützt."
            )
        case .supported, .downloading:
            if let request = try await AssetInventory.assetInstallationRequest(
                supporting: [module]
            ) {
                logger.info("Starte Asset-Download (~100 MB) …")
                try await request.downloadAndInstall()
                logger.info("Asset-Download abgeschlossen")
            } else {
                logger.warning("Kein Installationsrequest erhalten — Asset evtl. schon verfügbar")
            }
            // Erneut prüfen
            let after = await AssetInventory.status(forModules: [module])
            logger.info("Asset status nach: \(String(describing: after), privacy: .public)")
            if after != .installed {
                throw KirjoError.transcriptionFailed(
                    "Sprachmodell konnte nicht installiert werden (Status: \(String(describing: after)))."
                )
            }
        @unknown default:
            logger.warning("Unbekannter Asset-Status: \(String(describing: status), privacy: .public)")
        }
    }
}

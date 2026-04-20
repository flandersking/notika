import Foundation
import AVFoundation
import KirjoCore
import os
import WhisperKit

public final class WhisperKitEngine: TranscriptionEngine, @unchecked Sendable {
    public let id: TranscriptionEngineID = .whisperCpp
    public let supportsStreaming = false

    private let modelID: WhisperModelID
    private let modelStore: WhisperModelStore
    private var whisperKit: WhisperKit?
    private let logger = Logger(subsystem: "com.notika.mac", category: "Whisper")

    public init(modelID: WhisperModelID, modelStore: WhisperModelStore) {
        self.modelID = modelID
        self.modelStore = modelStore
    }

    public func transcribe(audio: AudioSource, language: Language, hints: [String]) async throws -> Transcript {
        let pipe = try await loadPipeIfNeeded()
        let audioURL = try await prepareAudio(audio)

        let initialPrompt = hints.isEmpty ? nil : hints.joined(separator: " ")
        let conditioningTokens: [Int]? = initialPrompt.flatMap { tokenize(prompt: $0, pipe: pipe) }

        // language: nil + detectLanguage default → Auto-Detect
        // usePrefillPrompt: true (also default) damit promptTokens als Konditionierung wirken können
        let decodeOptions = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: nil,
            temperature: 0,
            usePrefillPrompt: true,
            detectLanguage: true,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            wordTimestamps: false,
            promptTokens: conditioningTokens
        )

        let started = Date()
        let results: [TranscriptionResult]
        do {
            results = try await pipe.transcribe(audioPath: audioURL.path, decodeOptions: decodeOptions)
        } catch {
            logger.error("Whisper-Transkription fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            throw WhisperError.transcriptionFailed(reason: error.localizedDescription)
        }
        let elapsed = Date().timeIntervalSince(started)
        logger.info("Whisper OK: \(self.modelID.rawValue, privacy: .public), Dauer=\(String(format: "%.2f", elapsed))s")

        let combinedText = results.map(\.text).joined(separator: " ")
        let detectedLang = results.first.flatMap { Language(whisperCode: $0.language) }
        let segments: [Transcript.Segment] = results.flatMap { tr -> [Transcript.Segment] in
            tr.segments.map { seg in
                Transcript.Segment(
                    text: seg.text,
                    start: TimeInterval(seg.start),
                    end: TimeInterval(seg.end)
                )
            }
        }
        return Transcript(
            text: combinedText.trimmingCharacters(in: .whitespacesAndNewlines),
            segments: segments,
            detectedLanguage: detectedLang
        )
    }

    public func preWarm() async {
        do {
            _ = try await loadPipeIfNeeded()
            logger.info("Whisper Pre-Warm OK: \(self.modelID.rawValue, privacy: .public)")
        } catch {
            logger.warning("Whisper Pre-Warm fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadPipeIfNeeded() async throws -> WhisperKit {
        if let pipe = whisperKit { return pipe }
        let modelDir = await MainActor.run { modelStore.diskPath(for: modelID) }
        guard FileManager.default.fileExists(atPath: modelDir.path),
              let contents = try? FileManager.default.contentsOfDirectory(atPath: modelDir.path),
              !contents.isEmpty
        else {
            throw WhisperError.modelNotInstalled(modelID)
        }
        do {
            // WhisperKit 0.18 convenience init: modelFolder = local path, download = false,
            // load wird automatisch true wenn modelFolder gesetzt ist.
            let pipe = try await WhisperKit(
                modelFolder: modelDir.path,
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: false
            )
            whisperKit = pipe
            return pipe
        } catch {
            throw WhisperError.modelLoadFailed(reason: error.localizedDescription)
        }
    }

    /// Konvertiert ein freies Prompt-String in Token-IDs via Tokenizer der Pipe.
    /// Gibt nil zurück, wenn Tokenizer (noch) nicht verfügbar ist — Whisper läuft dann ohne Hints.
    private func tokenize(prompt: String, pipe: WhisperKit) -> [Int]? {
        guard let tokenizer = pipe.tokenizer else { return nil }
        let encoded = tokenizer.encode(text: prompt)
        return encoded.isEmpty ? nil : encoded
    }

    private func prepareAudio(_ audio: AudioSource) async throws -> URL {
        switch audio {
        case .file(let url):
            return url
        case .samples(let samples, let rate):
            let resampled = try AudioResampler.resampleTo16kMono(samples, inputSampleRate: rate)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("whisper-\(UUID().uuidString).wav")
            try writeWAV(samples: resampled, to: tempURL)
            return tempURL
        }
    }

    private func writeWAV(samples: [Float], to url: URL) throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        )!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let chan = buffer.floatChannelData {
            samples.withUnsafeBufferPointer { src in
                chan[0].update(from: src.baseAddress!, count: samples.count)
            }
        }
        try file.write(from: buffer)
    }
}

private extension Language {
    init?(whisperCode: String) {
        switch whisperCode.lowercased() {
        case "de", "german":  self = .german
        case "en", "english": self = .english
        default:              return nil
        }
    }
}

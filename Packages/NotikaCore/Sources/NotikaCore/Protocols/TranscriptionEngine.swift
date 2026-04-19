import Foundation

public enum TranscriptionEngineID: String, Codable, Sendable, CaseIterable {
    case appleSpeechAnalyzer
    case whisperCpp
}

public enum AudioSource: Sendable {
    case file(URL)
    case samples([Float], sampleRate: Double)
}

public protocol TranscriptionEngine: AnyObject, Sendable {
    var id: TranscriptionEngineID { get }
    var supportsStreaming: Bool { get }

    func transcribe(
        audio: AudioSource,
        language: Language,
        hints: [String]
    ) async throws -> Transcript

    /// Optionaler Pre-Warm: Modell laden / CoreML-Graph kompilieren,
    /// damit das erste echte `transcribe` ohne Cold-Start läuft.
    /// Default-Implementierung ist no-op — Engines ohne Cold-Start (z. B. Apple)
    /// müssen nichts überschreiben.
    func preWarm() async
}

public extension TranscriptionEngine {
    func preWarm() async { }
}

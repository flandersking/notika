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
}

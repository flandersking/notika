import Foundation

public enum PostProcessingEngineID: String, Codable, Sendable, CaseIterable {
    case none
    case appleFoundationModels
    case anthropic
    case openAI
    case google
    case ollama
}

public protocol PostProcessingEngine: AnyObject, Sendable {
    var id: PostProcessingEngineID { get }

    func process(
        transcript: String,
        mode: DictationMode,
        language: Language
    ) async throws -> ProcessedText
}

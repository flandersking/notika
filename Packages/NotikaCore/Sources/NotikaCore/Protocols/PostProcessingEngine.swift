import Foundation

public enum PostProcessingEngineID: String, Codable, Sendable, CaseIterable {
    case appleFoundationModels
    case anthropic
}

public protocol PostProcessingEngine: AnyObject, Sendable {
    var id: PostProcessingEngineID { get }

    func process(
        transcript: String,
        mode: DictationMode,
        language: Language
    ) async throws -> String
}

import Foundation
import NotikaCore

public enum PostProcessingEngineFactory {
    public static func availableEngines() -> [PostProcessingEngineID] {
        [.appleFoundationModels]
    }

    public static func makeEngine(_ id: PostProcessingEngineID) -> PostProcessingEngine {
        switch id {
        case .appleFoundationModels:
            return FoundationModelsEngine()
        case .anthropic:
            // Phase 1b — AnthropicEngine folgt.
            return FoundationModelsEngine()
        }
    }
}

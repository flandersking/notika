import Foundation
import NotikaCore

public enum PostProcessingEngineFactory {
    public static func makeEngine(for choice: LLMChoice) -> PostProcessingEngine? {
        switch choice {
        case .none:
            return nil
        case .appleFoundationModels:
            return FoundationModelsEngine()
        case .anthropic, .openAI, .google, .ollama:
            // Werden in Tasks 4-7 implementiert. Bis dahin: nil → DictationCoordinator
            // fällt automatisch auf Rohtranskript zurück.
            return nil
        }
    }
}

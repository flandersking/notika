import Foundation
import NotikaCore

public enum PostProcessingEngineFactory {
    /// Liefert die passende Engine-Instanz für eine LLMChoice.
    /// - Returns: `nil` für `.none` oder wenn ein Cloud-Provider ohne Key konfiguriert ist
    ///   → DictationCoordinator fällt automatisch auf das Rohtranskript zurück.
    public static func makeEngine(for choice: LLMChoice) -> PostProcessingEngine? {
        switch choice {
        case .none:
            return nil
        case .appleFoundationModels:
            return FoundationModelsEngine()
        case .anthropic(let model):
            guard let key = KeychainStore.key(for: .anthropic) else { return nil }
            return AnthropicEngine(model: model, apiKey: key)
        case .openAI(let model):
            guard let key = KeychainStore.key(for: .openAI) else { return nil }
            return OpenAIEngine(model: model, apiKey: key)
        case .google(let model):
            guard let key = KeychainStore.key(for: .google) else { return nil }
            return GoogleEngine(model: model, apiKey: key)
        case .ollama(let modelID):
            return OllamaEngine(modelID: modelID)
        }
    }
}

import Foundation

public enum LLMChoice: Codable, Sendable, Hashable {
    case none
    case appleFoundationModels
    case anthropic(AnthropicModel)
    case openAI(OpenAIModel)
    case google(GoogleModel)
    case ollama(modelID: String)

    public var displayName: String {
        switch self {
        case .none:                   return "Kein KI-Helfer — Text bleibt wie gesprochen"
        case .appleFoundationModels:  return "Apple (gratis, läuft auf deinem Mac)"
        case .anthropic(let m):       return m.displayName
        case .openAI(let m):          return m.displayName
        case .google(let m):          return m.displayName
        case .ollama(let id):         return "Ollama · \(id)"
        }
    }

    public var providerID: PostProcessingEngineID {
        switch self {
        case .none:                   return .none
        case .appleFoundationModels:  return .appleFoundationModels
        case .anthropic:              return .anthropic
        case .openAI:                 return .openAI
        case .google:                 return .google
        case .ollama:                 return .ollama
        }
    }
}

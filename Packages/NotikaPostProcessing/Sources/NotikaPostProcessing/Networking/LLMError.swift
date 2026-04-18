import Foundation

public enum LLMError: Error, Sendable, Equatable {
    case invalidKey
    case rateLimit(retryAfter: TimeInterval?)
    case network
    case timeout
    case serverError(status: Int, body: String)
    case invalidResponse
    case ollamaUnavailable
    case modelNotFound(String)

    public var userFacingMessage: String {
        switch self {
        case .invalidKey:        return "Schlüssel ungültig — in Einstellungen prüfen"
        case .rateLimit:         return "Anbieter-Limit erreicht — kurz warten"
        case .network, .timeout: return "KI-Helfer offline — Rohtext eingefügt"
        case .serverError:       return "Server-Fehler — Rohtext eingefügt"
        case .invalidResponse:   return "Antwort nicht lesbar — Rohtext eingefügt"
        case .ollamaUnavailable: return "Ollama nicht erreichbar — Rohtext eingefügt"
        case .modelNotFound:     return "Modell nicht verfügbar — in Einstellungen prüfen"
        }
    }
}

extension LLMError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidKey:                  return "invalidKey"
        case .rateLimit(let retryAfter):
            if let retryAfter { return "rateLimit(retryAfter: \(retryAfter)s)" }
            return "rateLimit"
        case .network:                     return "network"
        case .timeout:                     return "timeout"
        case .serverError(let status, _):  return "serverError(status: \(status))"
        case .invalidResponse:             return "invalidResponse"
        case .ollamaUnavailable:           return "ollamaUnavailable"
        case .modelNotFound:               return "modelNotFound"
        }
    }
}

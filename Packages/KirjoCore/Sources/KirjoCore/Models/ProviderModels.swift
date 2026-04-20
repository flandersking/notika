import Foundation

public enum AnthropicModel: String, Codable, CaseIterable, Sendable, Hashable {
    case haiku45  = "claude-haiku-4-5"
    case sonnet46 = "claude-sonnet-4-6"
    case opus47   = "claude-opus-4-7"

    public var displayName: String {
        switch self {
        case .haiku45:  return "Claude Haiku 4.5 (schnell, günstig)"
        case .sonnet46: return "Claude Sonnet 4.6 (empfohlen)"
        case .opus47:   return "Claude Opus 4.7 (präziseste)"
        }
    }
}

public enum OpenAIModel: String, Codable, CaseIterable, Sendable, Hashable {
    case nano54 = "gpt-5.4-nano"
    case mini54 = "gpt-5.4-mini"
    case full54 = "gpt-5.4"

    public var displayName: String {
        switch self {
        case .nano54: return "GPT-5.4 nano (sehr günstig)"
        case .mini54: return "GPT-5.4 mini (empfohlen)"
        case .full54: return "GPT-5.4 (präziseste)"
        }
    }
}

public enum GoogleModel: String, Codable, CaseIterable, Sendable, Hashable {
    case flashLite31Preview = "gemini-3.1-flash-lite-preview"
    case flash25            = "gemini-2.5-flash"
    case pro31Preview       = "gemini-3.1-pro-preview"

    public var displayName: String {
        switch self {
        case .flashLite31Preview: return "Gemini 3.1 Flash-Lite (Preview)"
        case .flash25:            return "Gemini 2.5 Flash (empfohlen)"
        case .pro31Preview:       return "Gemini 3.1 Pro (Preview)"
        }
    }
}

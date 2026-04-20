import Foundation

public enum DictationMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case literal
    case social
    case formal

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .literal: return "1:1 + Smart Punctuation"
        case .social: return "Social Media (mit Emojis)"
        case .formal: return "Formell (E-Mail)"
        }
    }

    public var shortName: String {
        switch self {
        case .literal: return "Literal"
        case .social: return "Social"
        case .formal: return "Formal"
        }
    }
}

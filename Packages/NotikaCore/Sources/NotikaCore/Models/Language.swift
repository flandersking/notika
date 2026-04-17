import Foundation

public enum Language: String, CaseIterable, Codable, Sendable, Identifiable {
    case german = "de"
    case english = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .german: return "Deutsch"
        case .english: return "English"
        }
    }

    public var localeIdentifier: String {
        switch self {
        case .german: return "de-DE"
        case .english: return "en-US"
        }
    }
}

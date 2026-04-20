import Foundation

public enum ModifierTrigger: String, Codable, CaseIterable, Sendable {
    case none          = "none"
    case fn            = "fn"
    case rightCommand  = "rightCommand"
    case rightOption   = "rightOption"

    public var displayName: String {
        switch self {
        case .none:         return "Keiner"
        case .fn:           return "Fn-Taste"
        case .rightCommand: return "Rechte ⌘-Taste"
        case .rightOption:  return "Rechte ⌥-Taste"
        }
    }
}

extension ModifierTrigger: Identifiable {
    public var id: String { rawValue }
}

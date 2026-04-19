import Foundation

public enum TriggerMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case pushToTalk
    case toggle

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pushToTalk: return "Halten (Push-to-Talk)"
        case .toggle:     return "Antippen (Toggle)"
        }
    }
}

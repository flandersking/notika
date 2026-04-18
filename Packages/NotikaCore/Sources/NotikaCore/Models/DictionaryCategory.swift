import Foundation

public enum DictionaryCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case general    = "general"
    case names      = "names"
    case companies  = "companies"
    case medical    = "medical"
    case technical  = "technical"

    public var displayName: String {
        switch self {
        case .general:    return "Allgemein"
        case .names:      return "Namen"
        case .companies:  return "Firmen"
        case .medical:    return "Medizin"
        case .technical:  return "Technik"
        }
    }
}

import Foundation
import Observation

public enum LLMChoice: String, Codable, Sendable, CaseIterable, Identifiable {
    case none
    case appleFoundationModels
    case anthropic // Phase 1b

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none:                 return "Kein LLM — Rohtranskript"
        case .appleFoundationModels: return "Apple Foundation Models (experimentell, 3B on-device)"
        case .anthropic:            return "Anthropic Claude (BYOK) — folgt in Phase 1b"
        }
    }

    public var isAvailable: Bool {
        switch self {
        case .none, .appleFoundationModels: return true
        case .anthropic: return false // wird in Phase 1b true
        }
    }
}

@MainActor
@Observable
public final class SettingsStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var llmChoice: LLMChoice {
        get {
            guard let raw = defaults.string(forKey: "notika.settings.llmChoice"),
                  let value = LLMChoice(rawValue: raw)
            else {
                // Default: "Kein LLM" — wir wollen den User nicht zum schwachen 3B-Modell zwingen.
                return .none
            }
            return value
        }
        set {
            defaults.set(newValue.rawValue, forKey: "notika.settings.llmChoice")
        }
    }

    public var defaultLanguage: String {
        get { defaults.string(forKey: "notika.settings.language") ?? "de" }
        set { defaults.set(newValue, forKey: "notika.settings.language") }
    }
}

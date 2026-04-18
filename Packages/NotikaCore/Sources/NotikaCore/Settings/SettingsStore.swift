import Foundation
import Observation

@MainActor
@Observable
public final class SettingsStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrateIfNeeded(defaults: defaults)
    }

    // MARK: - Global LLM-Wahl

    public var globalLLMChoice: LLMChoice {
        get {
            guard let data = defaults.data(forKey: "notika.settings.globalLLMChoice"),
                  let value = try? JSONDecoder().decode(LLMChoice.self, from: data)
            else {
                return .appleFoundationModels   // Phase-1b-1-Default (Wahl 6b)
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "notika.settings.globalLLMChoice")
            }
        }
    }

    // MARK: - STT-Engine

    public var sttEngineChoice: STTEngineChoice {
        get {
            guard let data = defaults.data(forKey: "notika.settings.sttEngineChoice"),
                  let value = try? JSONDecoder().decode(STTEngineChoice.self, from: data)
            else {
                return .apple
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "notika.settings.sttEngineChoice")
            }
        }
    }

    // MARK: - Pro-Modus-Override (leer = nutzt global)

    public func override(for mode: DictationMode) -> LLMChoice? {
        guard let data = defaults.data(forKey: overrideKey(for: mode)),
              let value = try? JSONDecoder().decode(LLMChoice.self, from: data)
        else { return nil }
        return value
    }

    public func setOverride(_ choice: LLMChoice?, for mode: DictationMode) {
        let key = overrideKey(for: mode)
        if let choice, let data = try? JSONEncoder().encode(choice) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public func effectiveChoice(for mode: DictationMode) -> LLMChoice {
        override(for: mode) ?? globalLLMChoice
    }

    private func overrideKey(for mode: DictationMode) -> String {
        "notika.settings.modeOverride.\(mode.rawValue)"
    }

    // MARK: - Migration vom Phase-1a-rawString-Format

    private static func migrateIfNeeded(defaults: UserDefaults) {
        let oldKey = "notika.settings.llmChoice"
        let newKey = "notika.settings.globalLLMChoice"
        guard defaults.data(forKey: newKey) == nil,
              let oldRaw = defaults.string(forKey: oldKey)
        else { return }

        let migrated: LLMChoice
        switch oldRaw {
        case "appleFoundationModels":
            migrated = .appleFoundationModels
        case "none":
            migrated = .none
        case "anthropic":
            // Phase-1a hatte keinen funktionalen Anthropic-Engine; sinnvoll auf Apple zurück.
            migrated = .appleFoundationModels
        default:
            migrated = .appleFoundationModels
        }
        if let data = try? JSONEncoder().encode(migrated) {
            defaults.set(data, forKey: newKey)
        }
        defaults.removeObject(forKey: oldKey)
    }
}

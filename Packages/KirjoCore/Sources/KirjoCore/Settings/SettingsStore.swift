import Foundation
import Observation

@MainActor
@Observable
public final class SettingsStore {
    private let defaults: UserDefaults

    // Stored Properties (observable von SwiftUI). UserDefaults-Persist in didSet.
    public var hotkeyConfigLiteral: ModeHotkeyConfig {
        didSet { saveHotkeyConfig(hotkeyConfigLiteral, key: "kirjo.hotkey.config.literal") }
    }
    public var hotkeyConfigSocial: ModeHotkeyConfig {
        didSet { saveHotkeyConfig(hotkeyConfigSocial, key: "kirjo.hotkey.config.social") }
    }
    public var hotkeyConfigFormal: ModeHotkeyConfig {
        didSet { saveHotkeyConfig(hotkeyConfigFormal, key: "kirjo.hotkey.config.formal") }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrateIfNeeded(defaults: defaults)
        self.hotkeyConfigLiteral = Self.loadHotkeyConfigStatic(defaults: defaults, key: "kirjo.hotkey.config.literal")
        self.hotkeyConfigSocial  = Self.loadHotkeyConfigStatic(defaults: defaults, key: "kirjo.hotkey.config.social")
        self.hotkeyConfigFormal  = Self.loadHotkeyConfigStatic(defaults: defaults, key: "kirjo.hotkey.config.formal")
    }

    // MARK: - Global LLM-Wahl

    public var globalLLMChoice: LLMChoice {
        get {
            guard let data = defaults.data(forKey: "kirjo.settings.globalLLMChoice"),
                  let value = try? JSONDecoder().decode(LLMChoice.self, from: data)
            else {
                return .appleFoundationModels   // Phase-1b-1-Default (Wahl 6b)
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "kirjo.settings.globalLLMChoice")
            }
        }
    }

    // MARK: - STT-Engine

    public var sttEngineChoice: STTEngineChoice {
        get {
            guard let data = defaults.data(forKey: "kirjo.settings.sttEngineChoice"),
                  let value = try? JSONDecoder().decode(STTEngineChoice.self, from: data)
            else {
                return .apple
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "kirjo.settings.sttEngineChoice")
            }
        }
    }

    // MARK: - Hotkey-Config pro Modus (Phase 1b-6)

    public func hotkeyConfig(for mode: DictationMode) -> ModeHotkeyConfig {
        switch mode {
        case .literal: return hotkeyConfigLiteral
        case .social:  return hotkeyConfigSocial
        case .formal:  return hotkeyConfigFormal
        }
    }

    public func setHotkeyConfig(_ config: ModeHotkeyConfig, for mode: DictationMode) {
        switch mode {
        case .literal: hotkeyConfigLiteral = config
        case .social:  hotkeyConfigSocial  = config
        case .formal:  hotkeyConfigFormal  = config
        }
    }

    private static func loadHotkeyConfigStatic(defaults: UserDefaults, key: String) -> ModeHotkeyConfig {
        guard let data = defaults.data(forKey: key),
              let config = try? JSONDecoder().decode(ModeHotkeyConfig.self, from: data) else {
            return ModeHotkeyConfig()
        }
        return config
    }

    private func saveHotkeyConfig(_ config: ModeHotkeyConfig, key: String) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: key)
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
        "kirjo.settings.modeOverride.\(mode.rawValue)"
    }

    // MARK: - Migration vom Phase-1a-rawString-Format

    private static func migrateIfNeeded(defaults: UserDefaults) {
        let oldKey = "kirjo.settings.llmChoice"
        let newKey = "kirjo.settings.globalLLMChoice"
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

import Foundation
import NotikaCore

/// Verwaltet die Modus-Prompts:
/// - Bundle-Defaults (aus den Markdown-Dateien unter `Prompts/`)
/// - User-Overrides (gespeichert in `UserDefaults`)
///
/// `effectivePrompt(for:)` liefert immer den aktuell wirksamen Prompt.
public enum PromptStore {

    // MARK: - Defaults aus Bundle

    public static func defaultPrompt(for mode: DictationMode) -> String {
        let resourceName: String
        switch mode {
        case .literal: resourceName = "mode_1_literal"
        case .social:  resourceName = "mode_2_social"
        case .formal:  resourceName = "mode_3_formal"
        }

        let url = Bundle.module.url(forResource: resourceName, withExtension: "md", subdirectory: "Prompts")
            ?? Bundle.module.url(forResource: resourceName, withExtension: "md")

        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else {
            return fallbackPrompt(for: mode)
        }
        return text
    }

    // MARK: - User-Overrides

    public static func customPrompt(for mode: DictationMode) -> String? {
        UserDefaults.standard.string(forKey: userDefaultsKey(for: mode))
    }

    public static func setCustomPrompt(_ text: String?, for mode: DictationMode) {
        let key = userDefaultsKey(for: mode)
        if let text, !text.isEmpty {
            UserDefaults.standard.set(text, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    public static func effectivePrompt(for mode: DictationMode) -> String {
        customPrompt(for: mode) ?? defaultPrompt(for: mode)
    }

    public static func resetAll() {
        for mode in DictationMode.allCases {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey(for: mode))
        }
    }

    // MARK: - Hilfen

    private static func userDefaultsKey(for mode: DictationMode) -> String {
        "notika.prompts.custom.\(mode.rawValue)"
    }

    private static func fallbackPrompt(for mode: DictationMode) -> String {
        // Hardcoded Fallback, falls Bundle-Resources fehlen (sollte nie passieren).
        switch mode {
        case .literal:
            return "Gib den Text wortgetreu zurück, korrigiere nur Satzzeichen und Groß-/Kleinschreibung."
        case .social:
            return "Formuliere den Text locker aus und füge 2–3 passende Emojis ein."
        case .formal:
            return "Formuliere den Text höflich und formell (Sie-Form) um, ohne den Inhalt zu verändern."
        }
    }
}

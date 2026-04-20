import Foundation
import KeyboardShortcuts
import KirjoCore

public extension KeyboardShortcuts.Name {
    static let modeLiteral = Self("kirjo.mode.literal")
    static let modeSocial = Self("kirjo.mode.social")
    static let modeFormal = Self("kirjo.mode.formal")
}

public enum HotkeyBinding {
    public static func name(for mode: DictationMode) -> KeyboardShortcuts.Name {
        switch mode {
        case .literal: return .modeLiteral
        case .social:  return .modeSocial
        case .formal:  return .modeFormal
        }
    }
}

import Foundation
import KeyboardShortcuts
import NotikaCore

public extension KeyboardShortcuts.Name {
    static let modeLiteral = Self("notika.mode.literal")
    static let modeSocial = Self("notika.mode.social")
    static let modeFormal = Self("notika.mode.formal")
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

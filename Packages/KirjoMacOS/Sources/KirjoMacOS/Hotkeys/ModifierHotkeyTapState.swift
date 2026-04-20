import Foundation
import KirjoCore

/// Pure State-Machine für CGEventTap-basierte Modifier-Erkennung.
/// Keine CG-Abhängigkeiten — rein testbar.
public struct ModifierHotkeyTapState: Sendable, Equatable {

    /// Physical-Input-Event aus dem CGEventTap-Callback,
    /// abstrahiert von CGEvent für die Testbarkeit.
    public enum Input: Sendable, Equatable {
        /// Modifier-Flags haben sich geändert. `flags` ist der aktuelle kombinierte Zustand.
        /// `keyCode` identifiziert welcher Modifier geklickt wurde (54=Right-Cmd, 61=Right-Option etc.).
        case flagsChanged(flags: Flags, keyCode: Int)
        /// Eine Nicht-Modifier-Taste wurde gedrückt (Cancel-Signal).
        case keyDown
        /// Hold-Schwelle (z.B. 100 ms) abgelaufen.
        case holdThresholdReached
    }

    /// Effekt, den der Tap nach außen schiebt.
    public enum Effect: Sendable, Equatable {
        case pressed
        case released
        case armingStarted    // Timer starten
        case armingCancelled  // Timer abbrechen
    }

    /// Abstrahierte Modifier-Flags (entsprechen NSEvent.ModifierFlags / CGEventFlags).
    public struct Flags: OptionSet, Sendable, Equatable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        public static let fn       = Flags(rawValue: 1 << 0)
        public static let command  = Flags(rawValue: 1 << 1)
        public static let option   = Flags(rawValue: 1 << 2)
        public static let shift    = Flags(rawValue: 1 << 3)
        public static let control  = Flags(rawValue: 1 << 4)
        public static let capsLock = Flags(rawValue: 1 << 5)
    }

    enum Phase: Sendable, Equatable {
        case idle
        case arming            // Modifier gedrückt, Hold-Schwelle nicht erreicht
        case triggered         // .pressed ausgelöst, Modifier noch gedrückt
    }

    public let configuredTrigger: ModifierTrigger
    var phase: Phase = .idle

    public init(configuredTrigger: ModifierTrigger) {
        self.configuredTrigger = configuredTrigger
    }

    /// Verarbeitet ein Input-Event und liefert den resultierenden Effect (oder nil).
    public mutating func handle(_ input: Input) -> Effect? {
        guard configuredTrigger != .none else { return nil }

        switch (phase, input) {
        case (.idle, .flagsChanged(let flags, let keyCode)):
            if matchesConfiguredTrigger(flags: flags, keyCode: keyCode) {
                phase = .arming
                return .armingStarted
            }
            return nil

        case (.arming, .flagsChanged(let flags, _)):
            if !matchesConfiguredTrigger(flags: flags, keyCode: 0) {
                phase = .idle
                return .armingCancelled
            }
            return nil

        case (.arming, .keyDown):
            phase = .idle
            return .armingCancelled

        case (.arming, .holdThresholdReached):
            phase = .triggered
            return .pressed

        case (.triggered, .flagsChanged(let flags, _)):
            if !matchesConfiguredTrigger(flags: flags, keyCode: 0) {
                phase = .idle
                return .released
            }
            return nil

        case (.triggered, .keyDown):
            phase = .idle
            return .released

        default:
            return nil
        }
    }

    /// Entscheidet, ob die aktuellen Flags exakt dem konfigurierten Trigger entsprechen
    /// (keine anderen Modifier, und bei Right-Cmd/Right-Option auch der korrekte keyCode).
    private func matchesConfiguredTrigger(flags: Flags, keyCode: Int) -> Bool {
        switch configuredTrigger {
        case .none:
            return false

        case .fn:
            return flags == .fn

        case .rightCommand:
            // Bei Release-Check (keyCode=0): Flag darf nicht mehr gesetzt sein, sonst false
            if keyCode == 0 {
                return flags == .command
            }
            return flags == .command && keyCode == 54

        case .rightOption:
            if keyCode == 0 {
                return flags == .option
            }
            return flags == .option && keyCode == 61
        }
    }
}

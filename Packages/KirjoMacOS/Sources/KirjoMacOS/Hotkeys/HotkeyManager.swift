import Foundation
import KeyboardShortcuts
import KirjoCore
import os

public enum HotkeyEvent: Sendable, Equatable {
    case pressed(DictationMode)
    case released(DictationMode)
}

@MainActor
public final class HotkeyManager {
    public typealias TriggerMode = KirjoCore.TriggerMode

    private let logger = Logger(subsystem: "de.dymny.kirjo.mac", category: "Hotkeys")
    private let continuation: AsyncStream<HotkeyEvent>.Continuation
    public let events: AsyncStream<HotkeyEvent>

    private lazy var modifierTap: ModifierHotkeyTap = {
        ModifierHotkeyTap { [weak self] mode, event in
            guard let self else { return }
            switch event {
            case .pressed:  self.continuation.yield(.pressed(mode))
            case .released: self.continuation.yield(.released(mode))
            }
        }
    }()

    public init() {
        var cont: AsyncStream<HotkeyEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    public func start() {
        for mode in DictationMode.allCases {
            let name = HotkeyBinding.name(for: mode)
            KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
                self?.logger.info("Hotkey pressed: \(mode.shortName, privacy: .public)")
                self?.continuation.yield(.pressed(mode))
            }
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                self?.logger.info("Hotkey released: \(mode.shortName, privacy: .public)")
                self?.continuation.yield(.released(mode))
            }
        }
        logger.info("HotkeyManager gestartet (Pfad A aktiv)")
    }

    /// Konfiguriert den Modifier-Tap (Pfad B) mit den aktuellen Config-Werten und startet
    /// oder stoppt ihn je nach Bedarf. Kann mehrfach aufgerufen werden.
    public func applyModifierConfigs(_ configs: [DictationMode: ModeHotkeyConfig]) {
        let anyActive = configs.values.contains { $0.modifierTrigger != .none }
        modifierTap.configure(configs: configs)

        if anyActive {
            do {
                try modifierTap.start()
                logger.info("ModifierHotkeyTap (Pfad B) aktiv")
            } catch ModifierHotkeyTap.StartError.accessibilityPermissionMissing {
                logger.warning("Pfad B inaktiv: Accessibility-Permission fehlt")
            } catch {
                logger.error("Pfad B Start fehlgeschlagen: \(String(describing: error), privacy: .public)")
            }
        } else {
            modifierTap.stop()
        }
    }

    public func stop() {
        for mode in DictationMode.allCases {
            KeyboardShortcuts.disable(HotkeyBinding.name(for: mode))
        }
        modifierTap.stop()
        continuation.finish()
    }
}

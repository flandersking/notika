import Foundation
import KeyboardShortcuts
import NotikaCore
import os

public enum HotkeyEvent: Sendable, Equatable {
    case pressed(DictationMode)
    case released(DictationMode)
}

@MainActor
public final class HotkeyManager {
    public enum TriggerMode: String, Codable, Sendable, CaseIterable, Identifiable {
        case pushToTalk
        case toggle

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .pushToTalk: return "Push-to-Talk (halten)"
            case .toggle:     return "Toggle (klick – klick)"
            }
        }
    }

    private let logger = Logger(subsystem: "com.notika.mac", category: "Hotkeys")
    private let continuation: AsyncStream<HotkeyEvent>.Continuation
    public let events: AsyncStream<HotkeyEvent>

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
        logger.info("HotkeyManager gestartet")
    }

    public func stop() {
        for mode in DictationMode.allCases {
            KeyboardShortcuts.disable(HotkeyBinding.name(for: mode))
        }
        continuation.finish()
    }
}

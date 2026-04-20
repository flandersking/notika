import AppKit
import CoreGraphics
import Foundation
import KirjoCore
import os

public enum ModifierHotkeyTapEvent: Sendable, Equatable {
    case pressed
    case released
}

/// Wrapper um einen CGEventTap, der pure State-Machine-Logik aus
/// ModifierHotkeyTapState mit CoreGraphics-Events verheiratet.
@MainActor
public final class ModifierHotkeyTap {
    private let logger = Logger(subsystem: "com.notika.mac", category: "ModifierTap")

    /// Millisekunden, die ein Modifier gehalten werden muss, bevor Press feuert.
    public static let holdThresholdMillis: Int = 100

    public typealias EventHandler = (DictationMode, ModifierHotkeyTapEvent) -> Void

    public enum StartError: Error {
        case accessibilityPermissionMissing
        case tapCreationFailed
    }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var stateByMode: [DictationMode: ModifierHotkeyTapState] = [:]
    private var armingTasks: [DictationMode: Task<Void, Never>] = [:]

    private let handler: EventHandler

    public init(handler: @escaping EventHandler) {
        self.handler = handler
    }

    public func configure(configs: [DictationMode: ModeHotkeyConfig]) {
        for task in armingTasks.values { task.cancel() }
        armingTasks.removeAll()

        stateByMode.removeAll()
        for (mode, cfg) in configs where cfg.modifierTrigger != .none {
            stateByMode[mode] = ModifierHotkeyTapState(configuredTrigger: cfg.modifierTrigger)
        }
        logger.info("ModifierHotkeyTap konfiguriert: \(self.stateByMode.count, privacy: .public) aktive Modi")
    }

    public func start() throws {
        guard AXIsProcessTrusted() else {
            logger.warning("Accessibility-Permission fehlt — ModifierHotkeyTap.start abgebrochen")
            throw StartError.accessibilityPermissionMissing
        }

        // Falls schon aktiv, nicht noch mal starten
        if tap != nil { return }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let this = Unmanaged<ModifierHotkeyTap>.fromOpaque(refcon).takeUnretainedValue()
                Task { @MainActor in
                    this.process(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            throw StartError.tapCreationFailed
        }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        logger.info("ModifierHotkeyTap gestartet")
    }

    public func stop() {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        tap = nil
        runLoopSource = nil
        for task in armingTasks.values { task.cancel() }
        armingTasks.removeAll()
        logger.info("ModifierHotkeyTap gestoppt")
    }

    // MARK: - Event-Processing

    private func process(type: CGEventType, event: CGEvent) {
        let input: ModifierHotkeyTapState.Input
        switch type {
        case .flagsChanged:
            let flags = Self.translateFlags(event.flags)
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            input = .flagsChanged(flags: flags, keyCode: keyCode)
        case .keyDown:
            input = .keyDown
        default:
            return
        }

        for mode in stateByMode.keys {
            guard var state = stateByMode[mode] else { continue }
            let effect = state.handle(input)
            stateByMode[mode] = state

            guard let effect else { continue }
            dispatch(effect: effect, for: mode)
        }
    }

    private func dispatch(effect: ModifierHotkeyTapState.Effect, for mode: DictationMode) {
        switch effect {
        case .armingStarted:
            let task = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(Self.holdThresholdMillis))
                if Task.isCancelled { return }
                guard let self else { return }
                guard var state = self.stateByMode[mode] else { return }
                if let nextEffect = state.handle(.holdThresholdReached) {
                    self.stateByMode[mode] = state
                    self.dispatch(effect: nextEffect, for: mode)
                }
            }
            armingTasks[mode] = task

        case .armingCancelled:
            armingTasks[mode]?.cancel()
            armingTasks[mode] = nil

        case .pressed:
            handler(mode, .pressed)

        case .released:
            armingTasks[mode]?.cancel()
            armingTasks[mode] = nil
            handler(mode, .released)
        }
    }

    // MARK: - CGEventFlags → State.Flags

    static func translateFlags(_ cg: CGEventFlags) -> ModifierHotkeyTapState.Flags {
        var result: ModifierHotkeyTapState.Flags = []
        if cg.contains(.maskSecondaryFn) { result.insert(.fn) }
        if cg.contains(.maskCommand)     { result.insert(.command) }
        if cg.contains(.maskAlternate)   { result.insert(.option) }
        if cg.contains(.maskShift)       { result.insert(.shift) }
        if cg.contains(.maskControl)     { result.insert(.control) }
        if cg.contains(.maskAlphaShift)  { result.insert(.capsLock) }
        return result
    }
}

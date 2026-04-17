import AppKit
import ApplicationServices
import Foundation
import os

public enum TextInserterResult: Sendable {
    /// Text wurde erfolgreich in die fokussierte App eingefügt (AX oder Paste).
    case inserted
    /// Text liegt in der Zwischenablage, konnte aber nicht automatisch
    /// eingefügt werden — meistens fehlt die Bedienungshilfen-Berechtigung.
    case clipboardOnly(reason: String)
}

/// Fügt Text in die aktuell fokussierte App ein.
///
/// Kaskade:
/// 1. **Accessibility API** — schreibt den Text direkt ins fokussierte
///    Text-Element der Vordergrund-App.
/// 2. **Clipboard-Fallback** — legt den Text auf das NSPasteboard und
///    simuliert ⌘V (wenn AX nicht verfügbar oder fehlschlägt).
///
/// Das Clipboard wird **immer** gesetzt (Sicherheitsnetz — der User kann
/// den Text manuell einfügen, falls beide Wege scheitern).
@MainActor
public final class TextInserter {

    public struct Options: Sendable {
        public var simulatePasteShortcut: Bool
        public var preferAccessibilityAPI: Bool
        public var restoreClipboard: Bool

        public init(
            simulatePasteShortcut: Bool = true,
            preferAccessibilityAPI: Bool = true,
            restoreClipboard: Bool = false
        ) {
            self.simulatePasteShortcut = simulatePasteShortcut
            self.preferAccessibilityAPI = preferAccessibilityAPI
            self.restoreClipboard = restoreClipboard
        }
    }

    private let logger = Logger(subsystem: "com.notika.mac", category: "TextInserter")
    private let options: Options

    public init(options: Options = .init()) {
        self.options = options
    }

    /// Fügt `text` in die fokussierte App ein.
    @discardableResult
    public func insert(_ text: String) async -> TextInserterResult {
        guard !text.isEmpty else { return .inserted }

        // Clipboard immer setzen — Sicherheitsnetz.
        let previous = options.restoreClipboard
            ? NSPasteboard.general.string(forType: .string)
            : nil
        setClipboard(text)

        // Ohne Bedienungshilfen-Freigabe können weder AX noch CGEvent-Paste
        // wirklich wirken — macOS filtert synthetische Keyboard-Events.
        guard AXIsProcessTrusted() else {
            logger.info("Accessibility nicht trusted — nur Clipboard gesetzt")
            return .clipboardOnly(reason: "Bitte Bedienungshilfen für Notika freigeben (Systemeinstellungen → Privatsphäre & Sicherheit → Bedienungshilfen). Text liegt solange in der Zwischenablage.")
        }

        var inserted = false
        if options.preferAccessibilityAPI {
            inserted = tryAccessibilityInsert(text)
        }

        if !inserted && options.simulatePasteShortcut {
            inserted = simulateCommandV()
        }

        // Clipboard optional zurücksetzen (nach kurzer Verzögerung, damit
        // ⌘V noch Zeit hatte, zu feuern).
        if let previous, options.restoreClipboard {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                self.setClipboard(previous)
            }
        }

        logger.info("insert(...) → inserted=\(inserted, privacy: .public), chars=\(text.count)")
        return inserted
            ? .inserted
            : .clipboardOnly(reason: "Weder AX- noch Paste-Einfügen hat funktioniert. Text liegt in der Zwischenablage.")
    }

    // MARK: - Accessibility API

    private func tryAccessibilityInsert(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else {
            logger.info("Accessibility nicht trusted — fallback auf Paste")
            return false
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard err == .success, let element = focusedRef else {
            logger.info("Kein fokussiertes AX-Element (Status: \(err.rawValue, privacy: .public))")
            return false
        }

        // Narrowing zu AXUIElement ohne Force-Cast.
        let focused = element as! AXUIElement

        // 1) Versuche, ausgewählten Text zu ersetzen (gängigste Variante).
        let setSelected = AXUIElementSetAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        if setSelected == .success {
            logger.info("AX kAXSelectedTextAttribute gesetzt")
            return true
        }

        // 2) Fallback: gesamten Wert überschreiben — nur sinnvoll bei leeren
        //    oder kurzen Feldern.
        var currentValueRef: CFTypeRef?
        let getValue = AXUIElementCopyAttributeValue(
            focused,
            kAXValueAttribute as CFString,
            &currentValueRef
        )
        if getValue == .success, let current = currentValueRef as? String {
            let combined = current + text
            let setValue = AXUIElementSetAttributeValue(
                focused,
                kAXValueAttribute as CFString,
                combined as CFTypeRef
            )
            if setValue == .success {
                logger.info("AX kAXValueAttribute überschrieben")
                return true
            }
        }

        logger.info("AX-Insert nicht erfolgreich (selected=\(setSelected.rawValue, privacy: .public)) — fallback")
        return false
    }

    // MARK: - Paste-Simulation

    private func simulateCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            logger.error("CGEventSource konnte nicht erstellt werden")
            return false
        }

        // V-Taste (kVK_ANSI_V = 9)
        let vKeyCode: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        return keyDown != nil && keyUp != nil
    }

    // MARK: - Pasteboard

    private func setClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

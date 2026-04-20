import AppKit
import ApplicationServices
import Foundation
import os

public enum TextInserterResult: Sendable {
    /// Text wurde an die fokussierte App via ⌘V gesendet. Ob sie das Paste
    /// tatsächlich konsumiert hat, können wir nicht zuverlässig prüfen — die
    /// allermeisten Apps (Notes, TextEdit, iTerm2, VS Code, Browser-Felder, …)
    /// reagieren auf den synthetischen Cmd+V-Event.
    case inserted
    /// Text liegt in der Zwischenablage, konnte aber nicht automatisch
    /// eingefügt werden — meistens fehlt die Bedienungshilfen-Berechtigung.
    case clipboardOnly(reason: String)
}

/// Fügt Text in die aktuell fokussierte App ein.
///
/// **Strategie (Phase 1b-1):** Universelles Pasteboard + ⌘V.
///
/// Die ursprüngliche Phase-1a-Kaskade (AX primär → Paste Fallback) hat in
/// Apps mit eigener Render-Engine (z.B. iTerm2, VS Code, Electron-Apps)
/// versagt: `AXUIElementSetAttributeValue` gibt dort `.success` zurück, ohne
/// dass tatsächlich Text erscheint. Da Cmd+V universell von praktisch allen
/// Text-aufnehmenden Apps verstanden wird, ist der AX-Direkt-Insert-Weg
/// entfernt — der Aufwand „erkennen welche App AX zuverlässig unterstützt"
/// lohnt sich nicht.
///
/// **Ablauf:**
/// 1. User-Clipboard sichern (String-Inhalt).
/// 2. Eigenen Text auf das NSPasteboard legen.
/// 3. Synthetisches ⌘V via CGEvent (HID-Tap) an die fokussierte App senden.
/// 4. Kurz warten, bis die Ziel-App das Paste verarbeitet hat.
/// 5. User-Clipboard wiederherstellen.
///
/// Voraussetzung: Bedienungshilfen-Freigabe. Ohne sie filtert macOS
/// synthetische Keyboard-Events — Result wird `.clipboardOnly`.
@MainActor
public final class TextInserter {

    public struct Options: Sendable {
        public var simulatePasteShortcut: Bool
        public var restoreClipboard: Bool
        /// Wartezeit zwischen Cmd+V-Post und Clipboard-Restore. Muss lang genug
        /// sein, damit die Ziel-App das Paste konsumiert hat — sonst paste-st
        /// sie den restaurierten alten Inhalt.
        public var pasteSettleMillis: Int

        public init(
            simulatePasteShortcut: Bool = true,
            restoreClipboard: Bool = true,
            pasteSettleMillis: Int = 150
        ) {
            self.simulatePasteShortcut = simulatePasteShortcut
            self.restoreClipboard = restoreClipboard
            self.pasteSettleMillis = pasteSettleMillis
        }
    }

    private let logger = Logger(subsystem: "de.dymny.kirjo.mac", category: "TextInserter")
    private let options: Options

    public init(options: Options = .init()) {
        self.options = options
    }

    /// Fügt `text` in die fokussierte App ein.
    @discardableResult
    public func insert(_ text: String) async -> TextInserterResult {
        guard !text.isEmpty else { return .inserted }

        // 1) User-Clipboard sichern (nur String, das ist für 99 % der Fälle ok).
        let previous = options.restoreClipboard
            ? NSPasteboard.general.string(forType: .string)
            : nil

        // 2) Eigenen Text auf das Clipboard legen — Sicherheitsnetz, falls ⌘V
        //    nicht funktioniert oder die App es nicht konsumiert.
        setClipboard(text)

        // Ohne Bedienungshilfen-Freigabe filtert macOS synthetische
        // Keyboard-Events. Dann bleibt nur das manuelle Paste durch den User.
        guard AXIsProcessTrusted() else {
            logger.info("Accessibility nicht trusted — nur Clipboard gesetzt")
            return .clipboardOnly(reason: "Bitte Bedienungshilfen für Kirjo freigeben (Systemeinstellungen → Privatsphäre & Sicherheit → Bedienungshilfen). Text liegt solange in der Zwischenablage.")
        }

        // 3) Cmd+V senden (kann via Options abgeschaltet werden, z.B. für Tests).
        guard options.simulatePasteShortcut else {
            logger.info("simulatePasteShortcut=false — Text bleibt im Clipboard")
            // Restore macht hier keinen Sinn (es wurde nicht gepasted).
            return .clipboardOnly(reason: "Auto-Paste deaktiviert. Text liegt in der Zwischenablage.")
        }

        guard simulateCommandV() else {
            logger.error("CGEvent Cmd+V konnte nicht erzeugt werden — nur Clipboard gesetzt")
            return .clipboardOnly(reason: "Cmd+V konnte nicht simuliert werden. Text liegt in der Zwischenablage.")
        }

        logger.info("⌘V gepostet, chars=\(text.count)")

        // 4 + 5) Warten und Clipboard restoren — im Hintergrund, damit die
        //        Pipeline nicht blockiert.
        if let previous, options.restoreClipboard {
            let settle = options.pasteSettleMillis
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(settle))
                self.setClipboard(previous)
            }
        }

        return .inserted
    }

    // MARK: - Paste-Simulation

    private func simulateCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            logger.error("CGEventSource konnte nicht erstellt werden")
            return false
        }

        // V-Taste (kVK_ANSI_V = 9)
        let vKeyCode: CGKeyCode = 9

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // .cghidEventTap ist der „echte" HID-Layer-Tap — wirkt für praktisch
        // alle Apps inkl. iTerm2/Terminal. .cgAnnotatedSessionEventTap (vorher
        // genutzt) wird von einigen Apps ignoriert.
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Pasteboard

    private func setClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

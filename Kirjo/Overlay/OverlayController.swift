import AppKit
import SwiftUI
import KirjoCore
import os

/// Verwaltet das NSPanel, das die Pill hostet. Das Fenster schwebt über
/// allen Apps, nimmt keinen Fokus, blockiert keine Maus-Events.
@MainActor
final class OverlayController {
    static let shared = OverlayController()

    private let logger = Logger(subsystem: "de.dymny.kirjo.mac", category: "Overlay")
    private var panel: NSPanel?

    let model = PillModel()

    func show() {
        ensurePanel()
        reposition()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func updateState(_ state: DictationState) {
        model.state = state
        if case .idle = state {
            // Waveform zurücksetzen und Fenster eine Kleinigkeit später ausblenden,
            // damit die Fade-Out-Animation sichtbar bleibt.
            model.resetHistory()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.hide()
            }
        } else {
            show()
        }
    }

    func pushAudioLevel(_ level: Float) {
        model.pushLevel(level)
    }

    // MARK: - Panel-Setup

    private func ensurePanel() {
        guard panel == nil else { return }

        let hosting = NSHostingController(
            rootView: PillView(model: model)
                .fixedSize(horizontal: true, vertical: true)
                .padding(24)
        )
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = .clear

        let panel = NSPanel(
            contentViewController: hosting
        )
        panel.styleMask = [.nonactivatingPanel, .borderless]
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false

        self.panel = panel
        logger.info("Overlay-Panel erstellt")
    }

    /// Positioniert die Pill 64 px über dem unteren Rand des Haupt-Screens.
    private func reposition() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.minY + 64
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

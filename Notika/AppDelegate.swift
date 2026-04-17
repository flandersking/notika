import AppKit
import SwiftUI
import NotikaMacOS
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let logger = Logger(subsystem: "com.notika.mac", category: "AppDelegate")

    /// Singleton-Zugriff für SwiftUI-Views, die das Onboarding öffnen wollen.
    static private(set) weak var shared: AppDelegate?

    private var onboardingWindow: NSWindow?
    private let coordinator = DictationCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        // Sicherstellen, dass die App als Menüleisten-Agent läuft (kein Dock-Icon).
        NSApp.setActivationPolicy(.accessory)
        Self.logger.info("Notika gestartet (accessory mode)")

        // Hotkey- und Audio-Orchestrierung starten.
        coordinator.start()

        let hasCompleted = UserDefaults.standard.bool(forKey: "notika.hasCompletedOnboarding")

        // Zeige das Onboarding automatisch beim ersten Start oder wenn TCC nach
        // einem Rebuild die Berechtigungen invalidiert hat.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            let checker = PermissionsChecker()
            let allGranted = checker.allGranted
            if !hasCompleted || !allGranted {
                Self.logger.info("Öffne Onboarding (completed=\(hasCompleted, privacy: .public), allGranted=\(allGranted, privacy: .public))")
                self?.showOnboarding()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Fenster schließen beendet die App NICHT.
        false
    }

    // MARK: - Onboarding

    func showOnboarding() {
        if let existing = onboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: OnboardingFlow(
            onDismiss: { [weak self] in self?.closeOnboarding() }
        ))

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Willkommen bei Notika"
        window.setContentSize(NSSize(width: 560, height: 480))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true

        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }
}

import AppKit
import SwiftUI
import KirjoCore
import KirjoMacOS
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let logger = Logger(subsystem: "de.dymny.kirjo.mac", category: "AppDelegate")

    /// Singleton-Zugriff für SwiftUI-Views, die das Onboarding öffnen wollen.
    static private(set) weak var shared: AppDelegate?

    private var onboardingWindow: NSWindow?
    private var llmHintWindow: NSWindow?
    private var whisperConfirmWindow: NSWindow?
    private let coordinator = DictationCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        // Sicherstellen, dass die App als Menüleisten-Agent läuft (kein Dock-Icon).
        NSApp.setActivationPolicy(.accessory)
        Self.logger.info("Kirjo gestartet (accessory mode)")

        // Hotkey- und Audio-Orchestrierung starten.
        coordinator.start()

        // Whisper-Modell im Hintergrund vorwärmen, damit das erste Diktat
        // keinen Cold-Start-Delay hat. Läuft mit niedriger Priorität.
        Task.detached(priority: .utility) { [coordinator] in
            await coordinator.preWarm()
        }

        let hasCompleted = UserDefaults.standard.bool(forKey: "kirjo.hasCompletedOnboarding")

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
        window.title = "Willkommen bei Kirjo"
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

    // MARK: - LLM-Hint

    /// Zeigt einmalig den First-Use-Hint, der den User darauf hinweist,
    /// dass er einen Cloud-LLM oder Ollama in den Einstellungen aktivieren kann.
    func showLLMHintSheet() {
        if let existing = llmHintWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: LLMHintSheet(
            onOpenSettings: { [weak self] in
                self?.closeLLMHintSheet()
                self?.openSettingsWindow()
            },
            onLater: { [weak self] in
                self?.closeLLMHintSheet()
            }
        ))

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Tipp"
        window.setContentSize(NSSize(width: 420, height: 280))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true

        self.llmHintWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeLLMHintSheet() {
        llmHintWindow?.close()
        llmHintWindow = nil
    }

    // MARK: - Whisper Download Confirmation

    /// Wird nach erfolgreichem Whisper-Modell-Download gezeigt und fragt,
    /// ob das frisch installierte Modell als Standard-Engine aktiviert werden soll.
    func showWhisperDownloadConfirmSheet(for model: WhisperModelID, onChoice: @escaping (Bool) -> Void) {
        if let existing = whisperConfirmWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: WhisperDownloadConfirmSheet(
            model: model,
            onActivate: { [weak self] in
                self?.closeWhisperConfirmSheet()
                onChoice(true)
            },
            onLater: { [weak self] in
                self?.closeWhisperConfirmSheet()
                onChoice(false)
            }
        ))

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Spracherkennung"
        window.setContentSize(NSSize(width: 460, height: 300))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true

        self.whisperConfirmWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeWhisperConfirmSheet() {
        whisperConfirmWindow?.close()
        whisperConfirmWindow = nil
    }

    private func openSettingsWindow() {
        // macOS 14+ Settings-Scene-Selector
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

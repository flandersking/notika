import SwiftUI
import NotikaCore

struct MenuBarContent: View {
    @Environment(\.openSettings) private var openSettings
    @AppStorage("notika.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            Text("Notika")
                .font(.headline)

            Divider()

            ForEach(DictationMode.allCases) { mode in
                Label(mode.displayName, systemImage: iconName(for: mode))
                    .foregroundStyle(.secondary)
            }

            Divider()

            if !hasCompletedOnboarding {
                Button("Einrichtung fortsetzen …") {
                    AppDelegate.shared?.showOnboarding()
                }
            }

            Button("Einstellungen …") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: [.command])

            Button("Berechtigungen prüfen …") {
                AppDelegate.shared?.showOnboarding()
            }

            Divider()

            Button("Notika beenden") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }

    private func iconName(for mode: DictationMode) -> String {
        switch mode {
        case .literal: return "text.bubble"
        case .social: return "face.smiling"
        case .formal: return "envelope"
        }
    }
}

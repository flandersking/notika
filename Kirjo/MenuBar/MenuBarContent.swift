import SwiftUI
import NotikaCore
import NotikaPostProcessing

struct MenuBarContent: View {
    @Environment(\.openSettings) private var openSettings
    @AppStorage("notika.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var costStore = CostStore()
    @State private var todaySnap: CostSnapshot = .init()
    @State private var monthSnap: CostSnapshot = .init()

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

            costSection

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

            Button("Notika beenden") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: [.command])
        }
        .onAppear { refresh() }
    }

    @ViewBuilder
    private var costSection: some View {
        Text(String(format: "Heute: %.2f $ · %d Diktate", todaySnap.totalUSD, todaySnap.callCount))
            .foregroundStyle(.secondary)
        Text(String(format: "Diesen Monat: %.2f $", monthSnap.totalUSD))
            .foregroundStyle(.secondary)
            .font(.caption)
        Button("Tageszähler zurücksetzen") {
            costStore.resetToday()
            refresh()
        }
    }

    private func refresh() {
        todaySnap = costStore.today()
        monthSnap = costStore.thisMonth()
    }

    private func iconName(for mode: DictationMode) -> String {
        switch mode {
        case .literal: return "text.bubble"
        case .social:  return "face.smiling"
        case .formal:  return "envelope"
        }
    }
}

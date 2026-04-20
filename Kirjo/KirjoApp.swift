import SwiftUI

@main
struct KirjoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            Label {
                Text("Kirjo")
            } icon: {
                Image(systemName: "waveform.badge.mic")
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}

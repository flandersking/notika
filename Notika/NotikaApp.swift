import SwiftUI

@main
struct NotikaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            Label {
                Text("Notika")
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

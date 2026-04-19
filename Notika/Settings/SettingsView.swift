import SwiftUI
import KeyboardShortcuts
import NotikaCore
import NotikaMacOS
import ApplicationServices

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Allgemein", systemImage: "gearshape") {
                GeneralTab()
            }
            Tab("Kurzbefehle", systemImage: "keyboard") {
                HotkeysTab()
            }
            Tab("Modi", systemImage: "text.badge.checkmark") {
                PromptsTab()
            }
            Tab("KI", systemImage: "sparkles") {
                AITab()
            }
            Tab("Wörterbuch", systemImage: "character.book.closed") {
                DictionaryTab()
            }
            Tab("Verlauf", systemImage: "clock.arrow.circlepath") {
                HistoryTab()
            }
            Tab("Über", systemImage: "info.circle") {
                AboutTab()
            }
        }
        .frame(minWidth: 720, minHeight: 440)
    }
}

struct GeneralTab: View {
    var body: some View {
        Form {
            Section {
                Text("Allgemein — folgt in Schritt 8")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// Benachrichtigungs-Name, den der HotkeysTab postet, wenn sich eine Modifier-/Trigger-
/// Konfiguration ändert. Der DictationCoordinator hört darauf und verdrahtet den
/// ModifierHotkeyTap live neu.
extension Notification.Name {
    static let notikaHotkeyConfigChanged = Notification.Name("notika.hotkey.config.changed")
}

struct HotkeysTab: View {
    @State private var settings = SettingsStore()
    @State private var accessibilityGranted = AXIsProcessTrusted()

    var body: some View {
        Form {
            if !accessibilityGranted {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Bedienungshilfen nicht aktiv")
                                .font(.headline)
                            Text("Damit Modifier-Trigger (Fn / Rechte ⌘ / Rechte ⌥) funktionieren, musst du Notika in den Systemeinstellungen unter **Datenschutz & Sicherheit → Bedienungshilfen** aktivieren. Die klassischen Tastenkombis funktionieren auch ohne.")
                                .font(.caption)
                            Button("Systemeinstellungen öffnen") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                hotkeyRow(for: .literal, label: "📝 Literal")
                Divider()
                hotkeyRow(for: .social, label: "💬 Social")
                Divider()
                hotkeyRow(for: .formal, label: "✉️ Formal")
            } header: {
                Text("Kurzbefehle pro Modus")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("**Tastenkombi**: klassische Shortcuts wie ⌘⌥1, F5 etc.")
                    Text("**Einzeltaste**: reine Modifier (Fn / rechte ⌘ / rechte ⌥) — die Library für Tastenkombis unterstützt diese nicht, deshalb eine eigene Auswahl.")
                    Text("**Auslöser**: _Halten_ = drücken und sprechen, loslassen stoppt. _Antippen_ = einmal drücken zum Start, nochmal zum Beenden.")
                    Text("Beide Auslöse-Wege sind parallel aktiv — setze Einzeltaste auf \"Keiner\", wenn du nur die Tastenkombi nutzen willst.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    @ViewBuilder
    private func hotkeyRow(for mode: DictationMode, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tastenkombi").font(.caption2).foregroundStyle(.secondary)
                    KeyboardShortcuts.Recorder(for: HotkeyBinding.name(for: mode))
                        .frame(width: 180)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Einzeltaste").font(.caption2).foregroundStyle(.secondary)
                    Picker("", selection: modifierBinding(for: mode)) {
                        ForEach(ModifierTrigger.allCases) { trigger in
                            Text(trigger.displayName).tag(trigger)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Auslöser").font(.caption2).foregroundStyle(.secondary)
                    Picker("", selection: triggerModeBinding(for: mode)) {
                        ForEach(TriggerMode.allCases) { tm in
                            Text(tm.displayName).tag(tm)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func modifierBinding(for mode: DictationMode) -> Binding<ModifierTrigger> {
        Binding(
            get: { settings.hotkeyConfig(for: mode).modifierTrigger },
            set: { newValue in
                var config = settings.hotkeyConfig(for: mode)
                config.modifierTrigger = newValue
                settings.setHotkeyConfig(config, for: mode)
                NotificationCenter.default.post(name: .notikaHotkeyConfigChanged, object: nil)
            }
        )
    }

    private func triggerModeBinding(for mode: DictationMode) -> Binding<TriggerMode> {
        Binding(
            get: { settings.hotkeyConfig(for: mode).triggerMode },
            set: { newValue in
                var config = settings.hotkeyConfig(for: mode)
                config.triggerMode = newValue
                settings.setHotkeyConfig(config, for: mode)
                NotificationCenter.default.post(name: .notikaHotkeyConfigChanged, object: nil)
            }
        )
    }
}

// EnginesTab lebt jetzt in `EnginesTab.swift`.
// DictionaryTab lebt jetzt in `DictionaryTab.swift`.

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Notika")
                .font(.title)
                .bold()
            Text("Version 0.1.0")
                .foregroundStyle(.secondary)
            Text("© 2026 Michael Dymny")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
}

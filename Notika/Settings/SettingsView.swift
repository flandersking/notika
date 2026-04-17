import SwiftUI
import KeyboardShortcuts
import NotikaMacOS

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
            Tab("Engines", systemImage: "cpu") {
                EnginesTab()
            }
            Tab("Wörterbuch", systemImage: "character.book.closed") {
                DictionaryTab()
            }
            Tab("Über", systemImage: "info.circle") {
                AboutTab()
            }
        }
        .frame(minWidth: 620, minHeight: 440)
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

struct HotkeysTab: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Modus 1 — Literal", name: .modeLiteral)
                KeyboardShortcuts.Recorder("Modus 2 — Social", name: .modeSocial)
                KeyboardShortcuts.Recorder("Modus 3 — Formell", name: .modeFormal)
            } header: {
                Text("Kurzbefehle")
            } footer: {
                Text("Halte eine Taste gedrückt oder drücke eine Kombination, um einen Kurzbefehl aufzuzeichnen. Klicke das ✕-Symbol, um ihn zu entfernen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Aktuell: Push-to-Talk (Taste halten). Umschaltung auf Toggle folgt in Phase 1b.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Auslöseverhalten")
            }
        }
        .formStyle(.grouped)
    }
}

// EnginesTab lebt jetzt in `EnginesTab.swift`.

struct DictionaryTab: View {
    var body: some View {
        Form {
            Section {
                Text("Wörterbuch — folgt in Phase 1b")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

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

import SwiftUI
import NotikaCore
import NotikaWhisper

struct TranscriptionTab: View {
    @State private var settings = SettingsStore()
    @State private var modelStore = WhisperModelStore()
    @State private var installed: [WhisperModelID] = []

    var body: some View {
        Form {
            Section {
                appleRow
                ForEach(WhisperModelID.allCases, id: \.self) { model in
                    WhisperModelRow(
                        model: model,
                        modelStore: modelStore,
                        isActive: isActive(model),
                        onActivate: { activate(.whisper(model)) },
                        onChange: {
                            reloadInstalled()
                            if installed.contains(model), settings.sttEngineChoice == .apple {
                                AppDelegate.shared?.showWhisperDownloadConfirmSheet(for: model) { activate in
                                    if activate {
                                        self.activate(.whisper(model))
                                    }
                                }
                            }
                        }
                    )
                }
            } header: {
                Text("Wer hört zu und schreibt deine Worte mit?")
            } footer: {
                Text("Klicke auf ein Modell, um es zu aktivieren. Apple ist immer verfügbar; Whisper-Modelle musst du erst laden.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { reloadInstalled() }
    }

    @ViewBuilder
    private var appleRow: some View {
        Button {
            activate(.apple)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isActiveApple ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isActiveApple ? Color.accentColor : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple SpeechAnalyzer")
                        .foregroundStyle(.primary)
                    Text("System · 0 MB · immer verfügbar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isActiveApple {
                    Label("aktiv", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var isActiveApple: Bool {
        if case .apple = settings.sttEngineChoice { return true }
        return false
    }

    private func isActive(_ model: WhisperModelID) -> Bool {
        if case .whisper(let m) = settings.sttEngineChoice, m == model { return true }
        return false
    }

    private func activate(_ choice: STTEngineChoice) {
        settings.sttEngineChoice = choice
    }

    private func reloadInstalled() {
        installed = modelStore.installedModels()
    }
}

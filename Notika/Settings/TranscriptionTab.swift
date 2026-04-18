import SwiftUI
import NotikaCore
import NotikaWhisper

struct TranscriptionTab: View {
    @State private var settings = SettingsStore()
    @State private var modelStore = WhisperModelStore()
    @State private var installed: [WhisperModelID] = []
    @State private var activeKind: ActiveKind = .apple
    @State private var activeWhisperModel: WhisperModelID = .turbo

    enum ActiveKind: String, CaseIterable, Identifiable {
        case apple, whisper
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .apple:   return "Apple SpeechAnalyzer (on-device, immer verfügbar)"
            case .whisper: return "Whisper (lokal)"
            }
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Aktive Spracherkennung", selection: $activeKind) {
                    ForEach(ActiveKind.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: activeKind) { _, _ in writeChoice() }

                if activeKind == .whisper {
                    Picker("Modell", selection: $activeWhisperModel) {
                        ForEach(installed, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .disabled(installed.isEmpty)
                    .onChange(of: activeWhisperModel) { _, _ in writeChoice() }
                    if installed.isEmpty {
                        Text("Lade unten ein Modell, um Whisper zu aktivieren.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Aktive Spracherkennung")
            }

            Section {
                appleRow
                ForEach(WhisperModelID.allCases, id: \.self) { model in
                    WhisperModelRow(model: model, modelStore: modelStore, isActive: isActive(model)) {
                        reloadInstalled()
                        if installed.contains(model), settings.sttEngineChoice == .apple {
                            AppDelegate.shared?.showWhisperDownloadConfirmSheet(for: model) { activate in
                                if activate {
                                    settings.sttEngineChoice = .whisper(model)
                                    activeKind = .whisper
                                    activeWhisperModel = model
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Modelle")
            }
        }
        .formStyle(.grouped)
        .task { loadFromSettings() }
    }

    @ViewBuilder
    private var appleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple SpeechAnalyzer")
                Text("System · 0 MB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if case .apple = settings.sttEngineChoice {
                Label("aktiv", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
    }

    private func isActive(_ model: WhisperModelID) -> Bool {
        if case .whisper(let m) = settings.sttEngineChoice, m == model { return true }
        return false
    }

    private func loadFromSettings() {
        installed = modelStore.installedModels()
        switch settings.sttEngineChoice {
        case .apple:
            activeKind = .apple
        case .whisper(let m):
            activeKind = .whisper
            activeWhisperModel = m
        }
    }

    private func reloadInstalled() {
        installed = modelStore.installedModels()
    }

    private func writeChoice() {
        switch activeKind {
        case .apple:
            settings.sttEngineChoice = .apple
        case .whisper:
            if installed.contains(activeWhisperModel) {
                settings.sttEngineChoice = .whisper(activeWhisperModel)
            }
        }
    }
}

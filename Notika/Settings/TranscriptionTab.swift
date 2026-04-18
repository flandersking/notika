import AppKit
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
                Text("Nutze „Aktivieren" beim jeweiligen Modell, um es einzuschalten. Apple ist immer verfügbar; Whisper-Modelle musst du erst laden.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Modell-Ordner im Finder öffnen") {
                        NSWorkspace.shared.open(modelStore.modelsDirectory)
                    }
                    Spacer()
                    Text(sizeOnDisk)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } footer: {
                Text("Modelle liegen in ~/Library/Application Support/Notika/WhisperModels/. Du kannst den ganzen Ordner gefahrlos im Finder löschen — Apple SpeechAnalyzer funktioniert weiter.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { reloadInstalled() }
    }

    private var sizeOnDisk: String {
        let totalBytes = modelStore.installedModels().reduce(Int64(0)) { acc, id in
            acc + folderSize(modelStore.diskPath(for: id))
        }
        if totalBytes == 0 { return "0 MB belegt" }
        let gb = Double(totalBytes) / 1_073_741_824.0
        if gb >= 1.0 { return String(format: "%.1f GB belegt", gb) }
        let mb = Double(totalBytes) / 1_048_576.0
        return String(format: "%.0f MB belegt", mb)
    }

    private func folderSize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    @ViewBuilder
    private var appleRow: some View {
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
            } else {
                Button("Aktivieren") { activate(.apple) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
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

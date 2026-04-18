import SwiftUI
import NotikaCore
import NotikaWhisper

struct WhisperModelRow: View {
    let model: WhisperModelID
    let modelStore: WhisperModelStore
    let isActive: Bool
    let onChange: () -> Void

    @State private var progress: WhisperModelDownloadProgress?
    @State private var installed: Bool = false
    @State private var deleteConfirm: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                    Text(humanReadableSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                trailingControl
            }
            if let progress {
                progressView(progress)
            }
        }
        .padding(.vertical, 4)
        .task { installed = modelStore.installedModels().contains(model) }
        .alert("Modell löschen?", isPresented: $deleteConfirm) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                try? modelStore.deleteModel(model)
                installed = false
                onChange()
            }
        } message: {
            Text("\(model.displayName) wird vom Datenträger entfernt.")
        }
    }

    private var humanReadableSize: String {
        let mb = Double(model.approximateBytes) / 1_048_576.0
        if mb >= 1_000 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    @ViewBuilder
    private var trailingControl: some View {
        if installed {
            HStack(spacing: 8) {
                if isActive {
                    Label("aktiv", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Label("installiert", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Button("Löschen", role: .destructive) {
                    deleteConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } else if let progress, case .downloading = progress.state {
            Button("Abbrechen") {
                modelStore.cancelDownload(model)
                self.progress = nil
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else {
            Button("Laden") { startDownload() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private func progressView(_ progress: WhisperModelDownloadProgress) -> some View {
        switch progress.state {
        case .pending, .downloading:
            HStack(spacing: 8) {
                ProgressView(value: progress.fractionCompleted)
                Text("\(Int(progress.fractionCompleted * 100)) %")
                    .font(.caption2)
                    .monospacedDigit()
            }
        case .completed:
            EmptyView()
        case .failed(let err):
            Label(err.userFacingMessage, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .font(.caption)
        case .cancelled:
            Label("Abgebrochen", systemImage: "xmark.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private func startDownload() {
        let p = modelStore.startDownload(model)
        progress = p
        Task { @MainActor in
            for _ in 0..<7200 {
                try? await Task.sleep(for: .seconds(1))
                if case .completed = p.state {
                    installed = true
                    onChange()
                    return
                }
                if case .failed = p.state { return }
                if case .cancelled = p.state { return }
            }
        }
    }
}

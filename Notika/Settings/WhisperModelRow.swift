import SwiftUI
import NotikaCore
import NotikaWhisper

struct WhisperModelRow: View {
    let model: WhisperModelID
    let modelStore: WhisperModelStore
    let isActive: Bool
    let onActivate: () -> Void
    let onChange: () -> Void

    @State private var progress: WhisperModelDownloadProgress?
    @State private var installed: Bool = false
    @State private var deleteConfirm: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: radioIcon)
                    .foregroundStyle(radioColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                trailingControl
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if installed, !isActive {
                    onActivate()
                }
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

    private var radioIcon: String {
        if isActive { return "largecircle.fill.circle" }
        if installed { return "circle" }
        return "arrow.down.circle.dotted"
    }

    private var radioColor: Color {
        if isActive { return .accentColor }
        return .secondary
    }

    private var subtitle: String {
        if installed && isActive { return "\(humanReadableSize) · aktiv" }
        if installed { return "\(humanReadableSize) · installiert" }
        return humanReadableSize
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
            Button("Löschen", role: .destructive) {
                deleteConfirm = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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

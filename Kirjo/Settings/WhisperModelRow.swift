import SwiftUI
import KirjoCore
import KirjoWhisper

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
                if !installed {
                    Image(systemName: "arrow.down.circle.dotted")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.body.weight(isActive ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    Text(subtitle)
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
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
        )
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
            HStack(spacing: 8) {
                if isActive {
                    activeBadge
                } else {
                    Button("Aktivieren") { onActivate() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
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

    private var activeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
            Text("AKTIV")
                .font(.caption.weight(.bold))
                .tracking(0.5)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.green, in: Capsule())
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
            // Kurzes Polling-Intervall, damit das Download-Complete-Event
            // ohne 1s-Verzögerung beim User ankommt.
            for _ in 0..<72000 {
                try? await Task.sleep(for: .milliseconds(100))
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

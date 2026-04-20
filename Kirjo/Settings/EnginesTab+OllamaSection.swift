import SwiftUI
import KirjoPostProcessing

struct OllamaSection: View {
    @Binding var modelID: String
    @State private var status: OllamaStatus = .idle
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                switch status {
                case .idle, .loading:
                    Picker("Modell", selection: $modelID) {
                        Text("(noch keine Auswahl)").tag("")
                    }
                    .disabled(true)
                case .available(let infos):
                    Picker("Modell", selection: $modelID) {
                        ForEach(infos, id: \.self) { info in
                            Text("\(info.name) (\(humanReadable(info.sizeBytes)))").tag(info.name)
                        }
                    }
                    .onChange(of: modelID) { _, _ in onChange() }
                case .empty, .unavailable:
                    Picker("Modell", selection: $modelID) {
                        Text("(keine Modelle)").tag("")
                    }
                    .disabled(true)
                }
                Button("Aktualisieren") { Task { await refresh() } }
            }
            statusBanner
        }
        .task { await refresh() }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch status {
        case .idle, .loading:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Suche Modelle …") }
                .font(.footnote).foregroundStyle(.secondary)
        case .available:
            Label("Verbunden mit localhost:11434", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.footnote)
        case .empty:
            VStack(alignment: .leading, spacing: 4) {
                Label("Ollama läuft, aber keine Modelle installiert.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).font(.footnote)
                Text("Im Terminal: `ollama pull llama3.2`")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        case .unavailable:
            VStack(alignment: .leading, spacing: 4) {
                Label("Ollama scheint nicht zu laufen.", systemImage: "xmark.octagon")
                    .foregroundStyle(.red).font(.footnote)
                Link("Ollama herunterladen", destination: URL(string: "https://ollama.com/download")!)
                    .font(.footnote)
            }
        }
    }

    private func refresh() async {
        status = .loading
        let discovery = OllamaModelDiscovery()
        do {
            let infos = try await discovery.installedModelInfos()
            if infos.isEmpty {
                status = .empty
            } else {
                status = .available(infos)
                let names = infos.map(\.name)
                if modelID.isEmpty || !names.contains(modelID) {
                    modelID = infos.first(where: { $0.name.contains(":latest") })?.name ?? infos.first?.name ?? ""
                    onChange()
                }
            }
        } catch {
            status = .unavailable
        }
    }

    private func humanReadable(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 1.0 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.0f MB", mb)
    }

    enum OllamaStatus {
        case idle, loading, available([OllamaModelInfo]), empty, unavailable
    }
}

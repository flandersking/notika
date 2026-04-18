import SwiftUI
import NotikaPostProcessing

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
                case .available(let models):
                    Picker("Modell", selection: $modelID) {
                        ForEach(models, id: \.self) { Text($0).tag($0) }
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
            let models = try await discovery.installedModels()
            if models.isEmpty {
                status = .empty
            } else {
                status = .available(models)
                if modelID.isEmpty || !models.contains(modelID) {
                    modelID = models.first(where: { $0.contains(":latest") }) ?? models.first ?? ""
                    onChange()
                }
            }
        } catch {
            status = .unavailable
        }
    }

    enum OllamaStatus {
        case idle, loading, available([String]), empty, unavailable
    }
}

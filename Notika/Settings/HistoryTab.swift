import SwiftUI
import NotikaCore

struct HistoryTab: View {
    @State private var historyStore = HistoryStore()
    @State private var entries: [DictationHistoryEntry] = []
    @State private var selectedEntry: DictationHistoryEntry?

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Noch keine Diktate",
                    systemImage: "text.bubble",
                    description: Text("Sobald du etwas diktiert hast, erscheint es hier.")
                )
            } else {
                List(entries) { entry in
                    HistoryRow(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedEntry = entry }
                }
            }
        }
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem {
                    Button("Alle löschen", role: .destructive) {
                        historyStore.deleteAll()
                        reload()
                    }
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            HistoryDetailSheet(entry: entry,
                               onDelete: {
                                   historyStore.delete(entry)
                                   selectedEntry = nil
                                   reload()
                               },
                               onClose: { selectedEntry = nil })
        }
        .task { reload() }
    }

    private func reload() {
        entries = historyStore.recent()
    }
}

private struct HistoryRow: View {
    let entry: DictationHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.timestamp, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                providerLabel
            }
            Text(entry.preview)
                .font(.body)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var providerLabel: some View {
        let provider = entry.provider ?? .none
        let cost = entry.costUSD.map { String(format: "%.4f $", $0) } ?? "lokal"
        Text("\(providerName(provider)) · \(cost)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private func providerName(_ p: PostProcessingEngineID) -> String {
        switch p {
        case .none:                  return "Rohtext"
        case .appleFoundationModels: return "Apple"
        case .anthropic:             return "Claude"
        case .openAI:                return "ChatGPT"
        case .google:                return "Gemini"
        case .ollama:                return "Ollama"
        }
    }
}

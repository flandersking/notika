import Foundation
import SwiftData

@MainActor
public final class HistoryStore {
    public let container: ModelContainer
    private let context: ModelContext
    public static let maxEntries = 20

    public init(container: ModelContainer? = nil) {
        if let container {
            self.container = container
        } else {
            // Production: persistente App-SQLite-DB
            let schema = Schema([DictationHistoryEntry.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            // swiftlint:disable:next force_try
            self.container = try! ModelContainer(for: schema, configurations: [config])
        }
        self.context = ModelContext(self.container)
    }

    public func append(
        text: String,
        mode: DictationMode,
        provider: PostProcessingEngineID,
        modelID: String?,
        costUSD: Double?
    ) {
        let entry = DictationHistoryEntry(
            timestamp: Date(),
            text: text,
            mode: mode,
            provider: provider,
            modelID: modelID,
            costUSD: costUSD
        )
        context.insert(entry)
        try? context.save()
        pruneOldest()
    }

    public func recent() -> [DictationHistoryEntry] {
        let descriptor = FetchDescriptor<DictationHistoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func delete(_ entry: DictationHistoryEntry) {
        context.delete(entry)
        try? context.save()
    }

    public func deleteAll() {
        for entry in recent() {
            context.delete(entry)
        }
        try? context.save()
    }

    private func pruneOldest() {
        let entries = recent()
        if entries.count > Self.maxEntries {
            let toDelete = entries.dropFirst(Self.maxEntries)
            for entry in toDelete {
                context.delete(entry)
            }
            try? context.save()
        }
    }
}

import XCTest
import SwiftData
@testable import KirjoCore

final class HistoryStoreTests: XCTestCase {
    var store: HistoryStore!

    @MainActor
    override func setUp() async throws {
        let schema = Schema([DictationHistoryEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        store = HistoryStore(container: container)
    }

    @MainActor
    func test_append_and_recent_returnsEntry() {
        store.append(text: "Hallo Welt", mode: .literal, provider: .anthropic, modelID: "claude-haiku-4-5", costUSD: 0.001)
        let entries = store.recent()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.text, "Hallo Welt")
        XCTAssertEqual(entries.first?.modelID, "claude-haiku-4-5")
        XCTAssertEqual(entries.first?.costUSD, 0.001)
    }

    @MainActor
    func test_recent_isOrderedByTimestampDescending() async throws {
        store.append(text: "Erster", mode: .literal, provider: .anthropic, modelID: nil, costUSD: nil)
        try await Task.sleep(for: .milliseconds(10))
        store.append(text: "Zweiter", mode: .literal, provider: .anthropic, modelID: nil, costUSD: nil)
        let entries = store.recent()
        XCTAssertEqual(entries.first?.text, "Zweiter")
        XCTAssertEqual(entries.last?.text, "Erster")
    }

    @MainActor
    func test_pruneOldest_keepsAtMost20() async throws {
        for i in 1...25 {
            store.append(text: "Diktat \(i)", mode: .literal, provider: .anthropic, modelID: nil, costUSD: nil)
            // Kleiner Sleep nicht nötig — der pruneOldest passiert in jedem append
        }
        let entries = store.recent()
        XCTAssertEqual(entries.count, HistoryStore.maxEntries)
        // Die jüngsten 20 müssen erhalten sein → "Diktat 25" als erstes
        XCTAssertEqual(entries.first?.text, "Diktat 25")
        XCTAssertEqual(entries.last?.text, "Diktat 6")
    }

    @MainActor
    func test_delete_removesEntry() {
        store.append(text: "Wegmachen", mode: .literal, provider: .anthropic, modelID: nil, costUSD: nil)
        let entries = store.recent()
        XCTAssertEqual(entries.count, 1)
        store.delete(entries.first!)
        XCTAssertEqual(store.recent().count, 0)
    }

    @MainActor
    func test_preview_truncatesAt80Chars() {
        let longText = String(repeating: "a", count: 200)
        store.append(text: longText, mode: .literal, provider: .anthropic, modelID: nil, costUSD: nil)
        let entry = store.recent().first!
        XCTAssertTrue(entry.preview.hasSuffix("…"))
        XCTAssertEqual(entry.preview.count, 81)   // 80 + …
    }
}

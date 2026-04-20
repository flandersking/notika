import XCTest
import SwiftData
@testable import KirjoDictionary
import KirjoCore

final class DictionaryStoreTests: XCTestCase {
    var container: ModelContainer!
    var store: DictionaryStore!

    override func setUp() async throws {
        let schema = Schema([DictionaryTerm.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        store = await DictionaryStore(container: container)
    }

    @MainActor
    func test_addTerm_appearsInAllTerms() {
        store.addTerm("Mdymny", language: .german, category: .names)
        let all = store.allTerms()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.term, "Mdymny")
        XCTAssertEqual(all.first?.language, .german)
        XCTAssertEqual(all.first?.category, .names)
    }

    @MainActor
    func test_addTerm_trimsWhitespace() {
        store.addTerm("  Mdymny  ", language: .german, category: .names)
        XCTAssertEqual(store.allTerms().first?.term, "Mdymny")
    }

    @MainActor
    func test_addTerm_emptyString_isIgnored() {
        store.addTerm("   ", language: .german, category: .general)
        XCTAssertEqual(store.allTerms().count, 0)
    }

    @MainActor
    func test_terms_filter_byLanguage() {
        store.addTerm("Haus", language: .german, category: .general)
        store.addTerm("House", language: .english, category: .general)
        XCTAssertEqual(store.terms(language: .german).count, 1)
        XCTAssertEqual(store.terms(language: .english).count, 1)
        XCTAssertEqual(store.terms(language: nil).count, 2)
    }

    @MainActor
    func test_terms_filter_byCategory() {
        store.addTerm("Mdymny", language: .german, category: .names)
        store.addTerm("Arztbrief", language: .german, category: .medical)
        XCTAssertEqual(store.terms(category: .names).count, 1)
        XCTAssertEqual(store.terms(category: .medical).count, 1)
        XCTAssertEqual(store.terms(category: nil).count, 2)
    }

    @MainActor
    func test_deleteTerm_removesIt() {
        store.addTerm("Eintrag", language: .german, category: .general)
        let entry = store.allTerms().first!
        store.deleteTerm(entry)
        XCTAssertEqual(store.allTerms().count, 0)
    }

    @MainActor
    func test_deleteAll_emptiesStore() {
        store.addTerm("A", language: .german, category: .general)
        store.addTerm("B", language: .english, category: .general)
        store.deleteAll()
        XCTAssertEqual(store.allTerms().count, 0)
    }

    @MainActor
    func test_updateTerm_savesChanges() {
        store.addTerm("Alt", language: .german, category: .general)
        let entry = store.allTerms().first!
        store.updateTerm(entry, newTerm: "Neu", newLanguage: .english, newCategory: .technical)
        let updated = store.allTerms().first!
        XCTAssertEqual(updated.term, "Neu")
        XCTAssertEqual(updated.language, .english)
        XCTAssertEqual(updated.category, .technical)
    }

    @MainActor
    func test_hintsForLanguage_returnsTermsOfThatLanguage() async {
        store.addTerm("Mdymny", language: .german, category: .names)
        store.addTerm("Hello", language: .english, category: .general)
        // Der Cache wird synchron im addTerm aktualisiert
        XCTAssertTrue(store.hintsForLanguage(.german).contains("Mdymny"))
        XCTAssertFalse(store.hintsForLanguage(.german).contains("Hello"))
        XCTAssertTrue(store.hintsForLanguage(.english).contains("Hello"))
    }

    @MainActor
    func test_hintsForLanguage_limitedTo100() {
        for i in 1...150 {
            store.addTerm("term-\(i)", language: .german, category: .general)
        }
        XCTAssertEqual(store.hintsForLanguage(.german).count, 100)
    }

    @MainActor
    func test_allTerms_sortedByUpdatedAtDesc() async {
        store.addTerm("Erster", language: .german, category: .general)
        try? await Task.sleep(for: .milliseconds(10))
        store.addTerm("Zweiter", language: .german, category: .general)
        let all = store.allTerms()
        XCTAssertEqual(all.first?.term, "Zweiter")
        XCTAssertEqual(all.last?.term, "Erster")
    }
}

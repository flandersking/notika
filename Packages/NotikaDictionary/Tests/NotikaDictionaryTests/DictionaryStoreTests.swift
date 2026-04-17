import XCTest
@testable import NotikaDictionary

final class DictionaryStoreTests: XCTestCase {
    func testInMemoryStoreReturnsEmptyHintsInitially() {
        let store = InMemoryDictionaryStore()
        XCTAssertTrue(store.hintsForLanguage(.german).isEmpty)
        XCTAssertTrue(store.hintsForLanguage(.english).isEmpty)
    }
}

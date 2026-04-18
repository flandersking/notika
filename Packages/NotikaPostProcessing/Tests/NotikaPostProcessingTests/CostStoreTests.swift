import XCTest
@testable import NotikaPostProcessing
import NotikaCore

final class CostStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: CostStore!

    @MainActor
    override func setUp() async throws {
        let suiteName = "test.notika.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = CostStore(defaults: defaults, calendar: Calendar(identifier: .gregorian))
    }

    @MainActor
    func test_record_increments_today() async {
        store.record(modelID: "claude-haiku-4-5", tokensIn: 1000, tokensOut: 500)
        let today = store.today()
        let expectedIn: Double = 1000.0 / 1_000_000.0 * 1.0
        let expectedOut: Double = 500.0 / 1_000_000.0 * 5.0
        let expected: Double = expectedIn + expectedOut
        XCTAssertEqual(today.callCount, 1)
        XCTAssertEqual(today.totalUSD, expected, accuracy: 0.0000001)
    }

    @MainActor
    func test_record_zero_for_unknown_model() async {
        store.record(modelID: "ollama:llama3.2", tokensIn: 1000, tokensOut: 500)
        let today = store.today()
        XCTAssertEqual(today.callCount, 1)
        XCTAssertEqual(today.totalUSD, 0)
    }

    @MainActor
    func test_today_resets_after_day_change() async {
        // Tag 1
        store.record(modelID: "claude-haiku-4-5", tokensIn: 1000, tokensOut: 1000)
        XCTAssertEqual(store.today().callCount, 1)
        // Simuliere Tageswechsel: Datum-Provider auf morgen setzen
        store.now = { Date().addingTimeInterval(86_400) }
        let day2 = store.today()
        XCTAssertEqual(day2.callCount, 0)
        XCTAssertEqual(day2.totalUSD, 0)
    }
}

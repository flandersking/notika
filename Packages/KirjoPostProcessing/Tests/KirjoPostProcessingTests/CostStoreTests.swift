import XCTest
@testable import KirjoPostProcessing
import KirjoCore

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
        store.record(costUSD: 0.0035)
        let today = store.today()
        XCTAssertEqual(today.callCount, 1)
        XCTAssertEqual(today.totalUSD, 0.0035, accuracy: 0.0000001)
    }

    @MainActor
    func test_record_nil_counts_but_adds_zero() async {
        store.record(costUSD: nil)
        let today = store.today()
        XCTAssertEqual(today.callCount, 1)
        XCTAssertEqual(today.totalUSD, 0)
    }

    @MainActor
    func test_today_resets_after_day_change() async {
        // Tag 1
        store.record(costUSD: 0.002)
        XCTAssertEqual(store.today().callCount, 1)
        // Simuliere Tageswechsel: Datum-Provider auf morgen setzen
        store.now = { Date().addingTimeInterval(86_400) }
        let day2 = store.today()
        XCTAssertEqual(day2.callCount, 0)
        XCTAssertEqual(day2.totalUSD, 0)
    }
}

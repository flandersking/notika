import XCTest
@testable import NotikaCore

final class ModifierTriggerTests: XCTestCase {
    func test_allCases_displayName_nonEmpty() {
        for trigger in ModifierTrigger.allCases {
            XCTAssertFalse(trigger.displayName.isEmpty, "\(trigger.rawValue) braucht displayName")
        }
    }

    func test_allCases_count_isFour() {
        XCTAssertEqual(ModifierTrigger.allCases.count, 4, "Erwartet: none, fn, rightCommand, rightOption")
    }

    func test_codable_roundtrip() throws {
        for trigger in ModifierTrigger.allCases {
            let data = try JSONEncoder().encode(trigger)
            let decoded = try JSONDecoder().decode(ModifierTrigger.self, from: data)
            XCTAssertEqual(trigger, decoded)
        }
    }
}

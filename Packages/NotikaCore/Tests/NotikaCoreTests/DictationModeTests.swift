import XCTest
@testable import NotikaCore

final class DictationModeTests: XCTestCase {
    func testAllModesHaveDisplayName() {
        for mode in DictationMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty)
            XCTAssertFalse(mode.shortName.isEmpty)
        }
    }

    func testLanguageLocaleIdentifiers() {
        XCTAssertEqual(Language.german.localeIdentifier, "de-DE")
        XCTAssertEqual(Language.english.localeIdentifier, "en-US")
    }
}

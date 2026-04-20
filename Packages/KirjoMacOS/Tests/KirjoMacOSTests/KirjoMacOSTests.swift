import XCTest
import KeyboardShortcuts
@testable import KirjoMacOS

final class KirjoMacOSTests: XCTestCase {
    func testHotkeyNamesAreDistinct() {
        let names: Set<String> = [
            KeyboardShortcuts.Name.modeLiteral.rawValue,
            KeyboardShortcuts.Name.modeSocial.rawValue,
            KeyboardShortcuts.Name.modeFormal.rawValue
        ]
        XCTAssertEqual(names.count, 3)
    }
}

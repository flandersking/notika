import XCTest
@testable import KirjoCore

final class ModeHotkeyConfigTests: XCTestCase {
    func test_defaultInit_noModifier_pushToTalk() {
        let config = ModeHotkeyConfig()
        XCTAssertEqual(config.modifierTrigger, .none)
        XCTAssertEqual(config.triggerMode, .pushToTalk)
    }

    func test_codable_roundtrip() throws {
        let original = ModeHotkeyConfig(modifierTrigger: .fn, triggerMode: .toggle)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModeHotkeyConfig.self, from: data)
        XCTAssertEqual(decoded.modifierTrigger, .fn)
        XCTAssertEqual(decoded.triggerMode, .toggle)
    }

    func test_equatable() {
        let a = ModeHotkeyConfig(modifierTrigger: .rightOption, triggerMode: .pushToTalk)
        let b = ModeHotkeyConfig(modifierTrigger: .rightOption, triggerMode: .pushToTalk)
        let c = ModeHotkeyConfig(modifierTrigger: .rightCommand, triggerMode: .pushToTalk)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

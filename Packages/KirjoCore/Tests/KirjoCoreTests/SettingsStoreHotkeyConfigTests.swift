import XCTest
@testable import NotikaCore

@MainActor
final class SettingsStoreHotkeyConfigTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "notika.tests.hotkey"

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    func test_defaults_areNoneAndPushToTalk() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.hotkeyConfigLiteral.modifierTrigger, .none)
        XCTAssertEqual(store.hotkeyConfigLiteral.triggerMode, .pushToTalk)
    }

    func test_set_persists_acrossInstances() {
        let storeA = SettingsStore(defaults: defaults)
        storeA.setHotkeyConfig(
            ModeHotkeyConfig(modifierTrigger: .fn, triggerMode: .toggle),
            for: .literal
        )
        let storeB = SettingsStore(defaults: defaults)
        XCTAssertEqual(storeB.hotkeyConfigLiteral.modifierTrigger, .fn)
        XCTAssertEqual(storeB.hotkeyConfigLiteral.triggerMode, .toggle)
    }

    func test_modeLookup_correctChannel() {
        let store = SettingsStore(defaults: defaults)
        store.setHotkeyConfig(ModeHotkeyConfig(modifierTrigger: .rightCommand, triggerMode: .pushToTalk), for: .formal)
        XCTAssertEqual(store.hotkeyConfig(for: .formal).modifierTrigger, .rightCommand)
        XCTAssertEqual(store.hotkeyConfig(for: .literal).modifierTrigger, .none)
    }
}

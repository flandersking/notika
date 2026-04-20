import XCTest
@testable import KirjoMacOS
import KirjoCore

final class ModifierHotkeyTapStateTests: XCTestCase {

    // MARK: - Keine Konfiguration

    func test_noneTrigger_ignoresAllEvents() {
        var state = ModifierHotkeyTapState(configuredTrigger: .none)
        XCTAssertNil(state.handle(.flagsChanged(flags: .fn, keyCode: 63)))
        XCTAssertNil(state.handle(.keyDown))
        XCTAssertNil(state.handle(.holdThresholdReached))
    }

    // MARK: - Fn (keyCode 63)

    func test_fn_alone_triggersArming() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        let effect = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        XCTAssertEqual(effect, .armingStarted)
    }

    func test_fn_plusOtherModifier_noArming() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        let effect = state.handle(.flagsChanged(flags: [.fn, .command], keyCode: 63))
        XCTAssertNil(effect)
    }

    func test_fn_holdThresholdReached_firesPressed() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        let effect = state.handle(.holdThresholdReached)
        XCTAssertEqual(effect, .pressed)
    }

    func test_fn_releasedBeforeThreshold_cancels() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        let effect = state.handle(.flagsChanged(flags: [], keyCode: 63))
        XCTAssertEqual(effect, .armingCancelled)
    }

    func test_fn_triggered_thenReleased_firesReleased() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        _ = state.handle(.holdThresholdReached)
        let effect = state.handle(.flagsChanged(flags: [], keyCode: 63))
        XCTAssertEqual(effect, .released)
    }

    func test_fn_arming_thenKeyDown_cancels() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        let effect = state.handle(.keyDown)
        XCTAssertEqual(effect, .armingCancelled)
    }

    func test_fn_triggered_thenKeyDown_cancelsWithRelease() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        _ = state.handle(.holdThresholdReached)
        let effect = state.handle(.keyDown)
        XCTAssertEqual(effect, .released)
    }

    // MARK: - Right-Command (keyCode 54)

    func test_rightCommand_correctKeyCode_triggersArming() {
        var state = ModifierHotkeyTapState(configuredTrigger: .rightCommand)
        let effect = state.handle(.flagsChanged(flags: .command, keyCode: 54))
        XCTAssertEqual(effect, .armingStarted)
    }

    func test_leftCommand_wrongKeyCode_doesNotArm() {
        var state = ModifierHotkeyTapState(configuredTrigger: .rightCommand)
        // Left-Cmd = keyCode 55
        let effect = state.handle(.flagsChanged(flags: .command, keyCode: 55))
        XCTAssertNil(effect)
    }

    // MARK: - Right-Option (keyCode 61)

    func test_rightOption_correctKeyCode_triggersArming() {
        var state = ModifierHotkeyTapState(configuredTrigger: .rightOption)
        let effect = state.handle(.flagsChanged(flags: .option, keyCode: 61))
        XCTAssertEqual(effect, .armingStarted)
    }

    func test_bothRightCmdAndRightOption_noArming() {
        var state = ModifierHotkeyTapState(configuredTrigger: .rightOption)
        // Beide Flags gesetzt → nicht exklusiv Option
        let effect = state.handle(.flagsChanged(flags: [.command, .option], keyCode: 61))
        XCTAssertNil(effect)
    }

    // MARK: - State-Integrity

    func test_cannotFirePressedTwice_withoutRelease() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        let first = state.handle(.holdThresholdReached)
        XCTAssertEqual(first, .pressed)
        // Nach Triggered sollte ein weiteres holdThresholdReached nichts mehr tun
        let second = state.handle(.holdThresholdReached)
        XCTAssertNil(second)
    }
}

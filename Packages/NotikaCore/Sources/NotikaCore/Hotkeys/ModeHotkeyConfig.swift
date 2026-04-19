import Foundation

public struct ModeHotkeyConfig: Codable, Sendable, Equatable {
    public var modifierTrigger: ModifierTrigger
    public var triggerMode: TriggerMode

    public init(
        modifierTrigger: ModifierTrigger = .none,
        triggerMode: TriggerMode = .pushToTalk
    ) {
        self.modifierTrigger = modifierTrigger
        self.triggerMode = triggerMode
    }
}

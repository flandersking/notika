import Foundation

public enum DictationState: Equatable, Sendable {
    case idle
    case recording(mode: DictationMode)
    case transcribing(mode: DictationMode)
    case processing(mode: DictationMode)
    case inserting(mode: DictationMode)
    case error(message: String)

    public var isBusy: Bool {
        switch self {
        case .idle, .error: return false
        default: return true
        }
    }
}

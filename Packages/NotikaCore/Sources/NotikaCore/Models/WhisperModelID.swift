import Foundation

public enum WhisperModelID: String, Codable, CaseIterable, Sendable, Hashable {
    case base    = "openai_whisper-base"
    case turbo   = "openai_whisper-large-v3-turbo"
    case largeV3 = "openai_whisper-large-v3"

    public var displayName: String {
        switch self {
        case .base:    return "Whisper Base (~80 MB, schnell)"
        case .turbo:   return "Whisper Turbo (~800 MB, empfohlen)"
        case .largeV3: return "Whisper Large V3 (~1,5 GB, maximalqualität)"
        }
    }

    public var approximateBytes: Int64 {
        switch self {
        case .base:    return 80  * 1_048_576
        case .turbo:   return 800 * 1_048_576
        case .largeV3: return 1_500 * 1_048_576
        }
    }
}

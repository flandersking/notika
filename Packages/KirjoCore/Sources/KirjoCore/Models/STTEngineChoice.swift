import Foundation

public enum STTEngineChoice: Codable, Sendable, Hashable {
    case apple
    case whisper(WhisperModelID)

    public var displayName: String {
        switch self {
        case .apple:           return "Apple SpeechAnalyzer"
        case .whisper(let m):  return m.displayName
        }
    }
}

import Foundation
import NotikaCore

public enum WhisperError: Error, Sendable, Equatable, CustomStringConvertible {
    case modelNotInstalled(WhisperModelID)
    case downloadFailed(reason: String)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case downloadCancelled
    case modelLoadFailed(reason: String)
    case audioResamplingFailed
    case transcriptionFailed(reason: String)

    public var userFacingMessage: String {
        switch self {
        case .modelNotInstalled(let m):
            return "Whisper-Modell „\(m.displayName)“ ist nicht geladen — bitte erneut laden"
        case .downloadFailed:
            return "Modell-Download fehlgeschlagen — bitte erneut versuchen"
        case .insufficientDiskSpace(let req, _):
            let gb = Double(req) / 1_073_741_824.0
            return String(format: "Nicht genug Speicherplatz frei (Modell braucht %.1f GB)", gb)
        case .downloadCancelled:
            return "Download abgebrochen"
        case .modelLoadFailed:
            return "Whisper-Modell konnte nicht geladen werden"
        case .audioResamplingFailed:
            return "Audio-Konvertierung fehlgeschlagen"
        case .transcriptionFailed:
            return "Transkription fehlgeschlagen — wechsle zu Apple SpeechAnalyzer"
        }
    }

    public var description: String {
        switch self {
        case .modelNotInstalled(let m):           return "modelNotInstalled(\(m.rawValue))"
        case .downloadFailed:                     return "downloadFailed"
        case .insufficientDiskSpace(let r, let a): return "insufficientDiskSpace(required: \(r), available: \(a))"
        case .downloadCancelled:                  return "downloadCancelled"
        case .modelLoadFailed:                    return "modelLoadFailed"
        case .audioResamplingFailed:              return "audioResamplingFailed"
        case .transcriptionFailed:                return "transcriptionFailed"
        }
    }
}

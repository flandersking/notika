import Foundation

public enum DictionaryError: Error, Sendable, Equatable, CustomStringConvertible {
    case csvMalformed(line: Int, reason: String)
    case fileReadFailed
    case fileWriteFailed

    public var userFacingMessage: String {
        switch self {
        case .csvMalformed(let line, _):
            return "CSV-Fehler in Zeile \(line)"
        case .fileReadFailed:
            return "Datei konnte nicht gelesen werden"
        case .fileWriteFailed:
            return "Datei konnte nicht geschrieben werden"
        }
    }

    public var description: String {
        switch self {
        case .csvMalformed(let line, _): return "csvMalformed(line: \(line))"
        case .fileReadFailed:            return "fileReadFailed"
        case .fileWriteFailed:           return "fileWriteFailed"
        }
    }
}

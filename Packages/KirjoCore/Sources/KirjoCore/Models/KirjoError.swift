import Foundation

public enum KirjoError: LocalizedError, Sendable {
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case accessibilityPermissionDenied
    case audioRecorderUnavailable
    case transcriptionFailed(String)
    case postProcessingFailed(String)
    case textInsertionFailed(String)
    case apiKeyMissing
    case engineNotAvailable(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Notika braucht Zugriff auf das Mikrofon. Bitte in den Systemeinstellungen freigeben."
        case .speechRecognitionPermissionDenied:
            return "Notika braucht Zugriff auf die Spracherkennung. Bitte in den Systemeinstellungen freigeben."
        case .accessibilityPermissionDenied:
            return "Notika braucht Bedienungshilfen-Zugriff, um Text in andere Apps einzufügen. Bitte in den Systemeinstellungen freigeben."
        case .audioRecorderUnavailable:
            return "Audioaufnahme ist aktuell nicht verfügbar."
        case .transcriptionFailed(let reason):
            return "Transkription fehlgeschlagen: \(reason)"
        case .postProcessingFailed(let reason):
            return "Nachbearbeitung fehlgeschlagen: \(reason)"
        case .textInsertionFailed(let reason):
            return "Text konnte nicht eingefügt werden: \(reason)"
        case .apiKeyMissing:
            return "Für die gewählte Cloud-Engine fehlt ein API-Schlüssel. Bitte in den Einstellungen hinterlegen."
        case .engineNotAvailable(let name):
            return "Die Engine »\(name)« ist nicht verfügbar."
        case .cancelled:
            return "Vorgang abgebrochen."
        }
    }
}

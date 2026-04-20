import AppKit
import AVFoundation
import ApplicationServices
import Observation
import Speech
import os

public enum PermissionStatus: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case restricted
    case granted

    public var isGranted: Bool { self == .granted }

    public var displayText: String {
        switch self {
        case .unknown: return "Unbekannt"
        case .notDetermined: return "Noch nicht angefragt"
        case .denied: return "Abgelehnt"
        case .restricted: return "Eingeschränkt"
        case .granted: return "Erteilt"
        }
    }
}

@MainActor
@Observable
public final class PermissionsChecker {
    public private(set) var microphone: PermissionStatus = .unknown
    public private(set) var speechRecognition: PermissionStatus = .unknown
    public private(set) var accessibility: PermissionStatus = .unknown

    private let logger = Logger(subsystem: "de.dymny.kirjo.mac", category: "Permissions")
    private var pollTask: Task<Void, Never>?

    public init() {
        refresh()
    }

    public var allGranted: Bool {
        microphone.isGranted && speechRecognition.isGranted && accessibility.isGranted
    }

    public func refresh() {
        microphone = Self.currentMicrophoneStatus()
        speechRecognition = Self.currentSpeechRecognitionStatus()
        accessibility = Self.currentAccessibilityStatus()
        logger.info("Permissions refreshed mic=\(self.microphone.displayText, privacy: .public) speech=\(self.speechRecognition.displayText, privacy: .public) ax=\(self.accessibility.displayText, privacy: .public)")
    }

    /// Startet ein kontinuierliches Polling aller Permissions — hilfreich, weil
    /// macOS den Bedienungshilfen-Status erst nach etwas Verzögerung aktualisiert,
    /// wenn der User ihn in den Systemeinstellungen umstellt.
    public func startPolling(interval: Duration = .seconds(1)) {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self else { break }
                self.refresh()
            }
        }
    }

    public func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Microphone

    public func requestMicrophoneAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            logger.info("Mic request result: \(granted, privacy: .public)")
        default:
            break
        }
        microphone = Self.currentMicrophoneStatus()
    }

    private static func currentMicrophoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .authorized: return .granted
        @unknown default: return .unknown
        }
    }

    // MARK: - Speech Recognition

    public func requestSpeechRecognitionAccess() async {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await Self.runSpeechAuthorizationPrompt()
        }
        speechRecognition = Self.currentSpeechRecognitionStatus()
    }

    /// `SFSpeechRecognizer.requestAuthorization` ruft seinen Completion-Handler
    /// auf einem Hintergrund-Thread auf. Wir isolieren den Aufruf deshalb
    /// explizit non-isolated, damit der Swift-6-Checker nicht abstürzt.
    private nonisolated static func runSpeechAuthorizationPrompt() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { _ in
                continuation.resume()
            }
        }
    }

    private static func currentSpeechRecognitionStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .authorized: return .granted
        @unknown default: return .unknown
        }
    }

    // MARK: - Accessibility

    /// Öffnet — falls nötig — den Berechtigungs-Prompt für Bedienungshilfen und
    /// aktualisiert anschließend den gespeicherten Status.
    public func requestAccessibilityAccess() {
        // Erst versuchen wir den System-Prompt. macOS unterdrückt ihn aber oft,
        // wenn die App bereits abgelehnt wurde oder der User weggeklickt hat —
        // deshalb öffnen wir zusätzlich direkt die Systemeinstellungen.
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: kCFBooleanTrue as Any] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        accessibility = Self.currentAccessibilityStatus()

        if accessibility != .granted {
            openAccessibilitySystemSettings()
        }
    }

    /// Öffnet den Systemeinstellungen-Bereich "Bedienungshilfen", damit der
    /// User die Berechtigung nachträglich erteilen kann.
    public func openAccessibilitySystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    public func openMicrophoneSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    public func openSpeechRecognitionSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private static func currentAccessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .notDetermined
    }
}

import SwiftUI
import NotikaMacOS

struct PermissionsStep: View {
    @Bindable var checker: PermissionsChecker
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Berechtigungen")
                    .font(.largeTitle).bold()
                Text("Notika braucht drei Freigaben, damit alles funktioniert.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .onAppear { checker.startPolling() }
            .onDisappear { checker.stopPolling() }

            ScrollView {
                VStack(spacing: 14) {
                    PermissionCard(
                        title: "Mikrofon",
                        description: "Damit Notika aufnehmen kann, was du sagst.",
                        icon: "mic.fill",
                        status: checker.microphone,
                        primaryAction: .init(
                            label: checker.microphone == .notDetermined ? "Zugriff erlauben" : "Systemeinstellungen öffnen",
                            action: {
                                if checker.microphone == .notDetermined {
                                    Task { await checker.requestMicrophoneAccess() }
                                } else {
                                    checker.openMicrophoneSystemSettings()
                                }
                            }
                        )
                    )

                    PermissionCard(
                        title: "Spracherkennung",
                        description: "Notwendig für on-device-Transkription mit Apple SpeechAnalyzer.",
                        icon: "waveform",
                        status: checker.speechRecognition,
                        primaryAction: .init(
                            label: checker.speechRecognition == .notDetermined ? "Zugriff erlauben" : "Systemeinstellungen öffnen",
                            action: {
                                if checker.speechRecognition == .notDetermined {
                                    Task { await checker.requestSpeechRecognitionAccess() }
                                } else {
                                    checker.openSpeechRecognitionSystemSettings()
                                }
                            }
                        )
                    )

                    PermissionCard(
                        title: "Bedienungshilfen",
                        description: "Erlaubt Notika, Text direkt in die fokussierte App einzufügen.",
                        icon: "keyboard",
                        status: checker.accessibility,
                        primaryAction: .init(
                            label: checker.accessibility == .notDetermined ? "Zugriff anfragen" : "Systemeinstellungen öffnen",
                            action: {
                                if checker.accessibility == .notDetermined {
                                    checker.requestAccessibilityAccess()
                                } else {
                                    checker.openAccessibilitySystemSettings()
                                }
                            }
                        )
                    )
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
            }

            Divider()

            HStack {
                Button("Status aktualisieren") { checker.refresh() }
                    .buttonStyle(.bordered)
                Spacer()
                Button(action: onContinue) {
                    Text(checker.allGranted ? "Weiter" : "Später nachholen")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

private struct PermissionCard: View {
    let title: String
    let description: String
    let icon: String
    let status: PermissionStatus
    let primaryAction: Action

    struct Action {
        let label: String
        let action: () -> Void
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .frame(width: 40, height: 40)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    StatusBadge(status: status)
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(primaryAction.label) { primaryAction.action() }
                .buttonStyle(.bordered)
                .disabled(status == .granted)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1)
        )
    }

    private var iconBackground: Color {
        switch status {
        case .granted: return Color.green.opacity(0.18)
        case .denied, .restricted: return Color.red.opacity(0.16)
        default: return Color.accentColor.opacity(0.14)
        }
    }
}

private struct StatusBadge: View {
    let status: PermissionStatus

    var body: some View {
        Text(status.displayText)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }

    private var background: Color {
        switch status {
        case .granted: return Color.green.opacity(0.18)
        case .denied, .restricted: return Color.red.opacity(0.18)
        default: return Color.secondary.opacity(0.18)
        }
    }

    private var foreground: Color {
        switch status {
        case .granted: return .green
        case .denied, .restricted: return .red
        default: return .secondary
        }
    }
}

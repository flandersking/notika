import SwiftUI
import NotikaMacOS

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case permissions
    case finished

    var title: String {
        switch self {
        case .welcome: return "Willkommen bei Notika"
        case .permissions: return "Berechtigungen erteilen"
        case .finished: return "Alles bereit"
        }
    }
}

struct OnboardingFlow: View {
    let onDismiss: () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var checker = PermissionsChecker()
    @AppStorage("notika.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome:
                    WelcomeStep {
                        step = .permissions
                    }
                case .permissions:
                    PermissionsStep(checker: checker) {
                        step = .finished
                    }
                case .finished:
                    FinishedStep {
                        hasCompletedOnboarding = true
                        onDismiss()
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            .animation(.snappy, value: step)
        }
        .frame(width: 560, height: 480)
        .background(.regularMaterial)
        .task { checker.refresh() }
    }
}

private struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(.tint)

            VStack(spacing: 10) {
                Text("Willkommen bei Notika")
                    .font(.largeTitle)
                    .bold()
                Text("Sprich — Notika tippt für dich.\nDrei Modi, eigene Hotkeys, volle Kontrolle.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onContinue) {
                Text("Los geht's")
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer().frame(height: 12)
        }
        .padding(.horizontal, 48)
    }
}

private struct FinishedStep: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            VStack(spacing: 10) {
                Text("Alles bereit")
                    .font(.largeTitle).bold()
                Text("Als Nächstes kannst du in den Einstellungen deine drei Kurzbefehle setzen.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onFinish) {
                Text("Fertig")
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer().frame(height: 12)
        }
        .padding(.horizontal, 48)
    }
}

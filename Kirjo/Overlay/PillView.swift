import SwiftUI
import KirjoCore

struct PillView: View {
    @Bindable var model: PillModel

    var body: some View {
        HStack(spacing: 10) {
            leadingIcon
                .frame(width: 14, height: 14)

            WaveformView(levels: model.levelHistory, tint: waveformTint)
                .frame(width: 120)

            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Capsule().fill(backgroundFill))
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        .animation(.easeInOut(duration: 0.2), value: isErrorState)
        .opacity(model.isVisible ? 1 : 0)
        .scaleEffect(model.isVisible ? 1 : 0.92)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: model.isVisible)
    }

    // MARK: - Dynamischer Content

    @ViewBuilder
    private var leadingIcon: some View {
        switch model.state {
        case .recording:
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 18, height: 18)
                        .blur(radius: 3)
                )
        case .initializing, .transcribing, .processing, .inserting:
            ProgressView()
                .scaleEffect(0.55)
                .tint(.white)
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.white)
        case .idle:
            Color.clear
        }
    }

    private var waveformTint: Color {
        switch model.state {
        case .recording: return .white
        case .initializing, .transcribing, .processing: return Color.white.opacity(0.5)
        case .inserting: return .green
        case .error: return .white
        case .idle: return .white
        }
    }

    /// Hintergrundfarbe der Pill — im Error-Fall orange, sonst Default-Schwarz.
    private var backgroundFill: Color {
        switch model.state {
        case .error: return .orange.opacity(0.95)
        case .recording, .initializing, .transcribing, .processing, .inserting, .idle:
            return .black.opacity(0.92)
        }
    }

    private var isErrorState: Bool {
        if case .error = model.state { return true }
        return false
    }

    private var label: String {
        switch model.state {
        case .recording(let mode):
            return "Aufnahme · \(mode.shortName)"
        case .initializing:
            return "Whisper lädt …"
        case .transcribing:
            return "Transkribiere …"
        case .processing:
            return "Bearbeite …"
        case .inserting:
            return "Füge ein …"
        case .error(let message):
            return message
        case .idle:
            return ""
        }
    }
}

#Preview("Recording") {
    let model = PillModel()
    model.state = .recording(mode: .literal)
    model.levelHistory = (0..<16).map { _ in Float.random(in: 0.1...0.9) }
    return ZStack {
        Color.gray.opacity(0.4)
        PillView(model: model)
    }
    .frame(width: 400, height: 100)
}

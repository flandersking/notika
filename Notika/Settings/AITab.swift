import SwiftUI

struct AITab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pipelineBanner
                sttSection
                llmSection
            }
            .padding(24)
        }
    }

    private var pipelineBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("So arbeitet Notika in zwei Schritten")
                .font(.headline)
            HStack(spacing: 12) {
                pipelineBox(icon: "mic.fill", title: "Du sprichst", subtitle: nil, color: .blue)
                pipelineArrow
                pipelineBox(icon: "waveform.badge.mic", title: "1. Spracherkennung", subtitle: "Apple oder Whisper", color: .purple)
                pipelineArrow
                pipelineBox(icon: "sparkles", title: "2. Textbearbeitung (optional)", subtitle: "Claude, ChatGPT, …", color: .pink)
                pipelineArrow
                pipelineBox(icon: "doc.text", title: "Fertig in App", subtitle: nil, color: .green)
            }
            Text("Wähle unten beides aus. Die Spracherkennung wandelt deine Stimme in rohen Text um — die Textbearbeitung macht ihn schön (Punktuation, Emojis, formelle Anrede usw.).")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func pipelineBox(icon: String, title: String, subtitle: String?, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .padding(8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var pipelineArrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    private var sttSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.badge.mic")
                    .foregroundStyle(.purple)
                Text("Spracherkennung")
                    .font(.title2).bold()
            }
            Text("Wer hört zu und schreibt deine Worte mit?")
                .font(.callout)
                .foregroundStyle(.secondary)
            TranscriptionTab()
                .frame(minHeight: 360)
        }
    }

    private var llmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.pink)
                Text("Textbearbeitung")
                    .font(.title2).bold()
            }
            Text("**Optional.** Wer poliert den erkannten Text? (Punktuation, Emojis, formelle Anrede). Nur nötig, wenn du KI-Polishing willst — wer „Kein KI-Helfer“ wählt, bekommt den Rohtext direkt.")
                .font(.callout)
                .foregroundStyle(.secondary)
            EnginesTab()
                .frame(minHeight: 320)
        }
    }
}

#Preview {
    AITab().frame(width: 720, height: 800)
}

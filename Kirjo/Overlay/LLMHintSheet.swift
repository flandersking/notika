import SwiftUI

struct LLMHintSheet: View {
    let onOpenSettings: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Tipp: Mit KI-Helfer wird's besser")
                .font(.title2).bold()
            Text("Mit einem Cloud-LLM oder Ollama wird das Ergebnis deutlich besser. Jetzt einrichten?")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            HStack {
                Button("Später", action: onLater)
                Spacer()
                Button("Einstellungen öffnen") { onOpenSettings() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(width: 420)
    }
}

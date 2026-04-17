import SwiftUI
import NotikaCore

struct EnginesTab: View {
    @State private var settings = SettingsStore()

    var body: some View {
        Form {
            Section {
                Picker("Nachbearbeitung", selection: Binding(
                    get: { settings.llmChoice },
                    set: { settings.llmChoice = $0 }
                )) {
                    ForEach(LLMChoice.allCases) { choice in
                        Text(choice.displayName)
                            .tag(choice)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("LLM für die drei Modi")
            } footer: {
                footer
            }

            Section {
                LabeledContent("Transkription") {
                    Text("Apple SpeechAnalyzer (on-device, macOS 26)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Speech-to-Text")
            } footer: {
                Text("In Phase 1b kommt whisper.cpp mit downloadbaren Modellen (Large V3 Turbo, Medium, Small) dazu.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("• **Kein LLM — Rohtranskript:** Der Text geht 1:1 aus dem SpeechAnalyzer in die Zwischenablage. Schnellste Variante.")
            Text("• **Apple Foundation Models:** On-device, gratis, aber das 3B-Modell ist klein und neigt zu Halluzinationen. Empfohlen nur für einfache Aufgaben.")
            Text("• **Claude BYOK (Phase 1b):** Eigener Anthropic-API-Key. Beste Qualität, schnelles Haiku 4.5 oder präziseres Sonnet 4.6. Kommt bald.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    EnginesTab().frame(width: 620, height: 360)
}

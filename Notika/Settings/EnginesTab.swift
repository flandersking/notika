import SwiftUI
import NotikaCore

struct EnginesTab: View {
    @State private var settings = SettingsStore()

    /// Vorerst nur die in Phase 1b-1 Task 1 funktional verfügbaren Choices.
    /// Die volle Picker-UI mit allen Providern + Modellen folgt in späterem Task.
    private let availableChoices: [LLMChoice] = [
        .none,
        .appleFoundationModels
    ]

    var body: some View {
        Form {
            Section {
                Picker("Nachbearbeitung", selection: Binding(
                    get: { settings.globalLLMChoice },
                    set: { settings.globalLLMChoice = $0 }
                )) {
                    ForEach(availableChoices, id: \.self) { choice in
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
            Text("• **Claude / ChatGPT / Gemini / Ollama (Phase 1b-1):** Provider-Auswahl folgt im neuen Settings-Flow.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    EnginesTab().frame(width: 620, height: 360)
}

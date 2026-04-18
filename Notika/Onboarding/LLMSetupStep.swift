import SwiftUI
import NotikaCore
import NotikaPostProcessing

struct LLMSetupStep: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var settings = SettingsStore()
    @State private var kind: ProviderKind = .apple
    @State private var anthropicModel: AnthropicModel = .haiku45
    @State private var openAIModel: OpenAIModel = .mini54
    @State private var googleModel: GoogleModel = .flash25
    @State private var apiKey: String = ""
    @State private var ollamaModel: String = ""
    @State private var inlineError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("Wer poliert deinen Text? (LLM)")
                    .font(.title).bold()
                Text("Optional — du kannst es jetzt einrichten oder später in den Einstellungen.")
                    .foregroundStyle(.secondary)
            }

            Picker("KI-Helfer", selection: $kind) {
                ForEach(ProviderKind.allCases) { k in
                    Text(k.displayName).tag(k)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            switch kind {
            case .apple, .none:
                EmptyView()
            case .anthropic:
                Picker("Modell", selection: $anthropicModel) {
                    ForEach(AnthropicModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                SecureField("API-Key (sk-ant-…)", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            case .openAI:
                Picker("Modell", selection: $openAIModel) {
                    ForEach(OpenAIModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                SecureField("API-Key (sk-…)", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            case .google:
                Picker("Modell", selection: $googleModel) {
                    ForEach(GoogleModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                SecureField("API-Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            case .ollama:
                OllamaSection(modelID: $ollamaModel) {}
            }

            if let inlineError {
                Label(inlineError, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Spacer()

            HStack {
                Button("Überspringen") {
                    settings.globalLLMChoice = .appleFoundationModels   // Wahl 6b
                    UserDefaults.standard.set(false, forKey: "notika.onboarding.llmStepCompleted")
                    onSkip()
                }
                Spacer()
                Button("Weiter") {
                    Task { await commit() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 16)
    }

    private func commit() async {
        inlineError = nil
        switch kind {
        case .none:
            settings.globalLLMChoice = .none
        case .apple:
            settings.globalLLMChoice = .appleFoundationModels
        case .anthropic:
            guard !apiKey.isEmpty else { inlineError = "API-Key fehlt"; return }
            do {
                let engine = AnthropicEngine(model: anthropicModel, apiKey: apiKey)
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
            } catch let err as LLMError {
                inlineError = err.userFacingMessage; return
            } catch {
                inlineError = "Unbekannter Fehler"; return
            }
            KeychainStore.setKey(apiKey, for: .anthropic)
            settings.globalLLMChoice = .anthropic(anthropicModel)
        case .openAI:
            guard !apiKey.isEmpty else { inlineError = "API-Key fehlt"; return }
            do {
                let engine = OpenAIEngine(model: openAIModel, apiKey: apiKey)
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
            } catch let err as LLMError {
                inlineError = err.userFacingMessage; return
            } catch {
                inlineError = "Unbekannter Fehler"; return
            }
            KeychainStore.setKey(apiKey, for: .openAI)
            settings.globalLLMChoice = .openAI(openAIModel)
        case .google:
            guard !apiKey.isEmpty else { inlineError = "API-Key fehlt"; return }
            do {
                let engine = GoogleEngine(model: googleModel, apiKey: apiKey)
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
            } catch let err as LLMError {
                inlineError = err.userFacingMessage; return
            } catch {
                inlineError = "Unbekannter Fehler"; return
            }
            KeychainStore.setKey(apiKey, for: .google)
            settings.globalLLMChoice = .google(googleModel)
        case .ollama:
            guard !ollamaModel.isEmpty else { inlineError = "Bitte ein Modell wählen"; return }
            settings.globalLLMChoice = .ollama(modelID: ollamaModel)
        }
        UserDefaults.standard.set(true, forKey: "notika.onboarding.llmStepCompleted")
        onContinue()
    }
}

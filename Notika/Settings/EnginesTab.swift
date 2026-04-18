import SwiftUI
import NotikaCore
import NotikaPostProcessing

/// Provider-Kategorie für den Top-Picker. Mappt auf konkrete LLMChoice-cases.
enum ProviderKind: String, CaseIterable, Identifiable {
    case none, apple, anthropic, openAI, google, ollama
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:      return "Kein KI-Helfer — Text bleibt wie gesprochen"
        case .apple:     return "Apple (gratis, läuft auf deinem Mac)"
        case .anthropic: return "Claude (von Anthropic, kostenpflichtig)"
        case .openAI:    return "ChatGPT (von OpenAI, kostenpflichtig)"
        case .google:    return "Gemini (von Google, kostenpflichtig)"
        case .ollama:    return "Lokales Modell via Ollama"
        }
    }
}

extension LLMChoice {
    var kind: ProviderKind {
        switch self {
        case .none:                  return .none
        case .appleFoundationModels: return .apple
        case .anthropic:             return .anthropic
        case .openAI:                return .openAI
        case .google:                return .google
        case .ollama:                return .ollama
        }
    }
}

struct EnginesTab: View {
    @State private var settings = SettingsStore()
    @State private var globalKind: ProviderKind = .apple
    @State private var anthropicModel: AnthropicModel = .haiku45
    @State private var openAIModel: OpenAIModel = .mini54
    @State private var googleModel: GoogleModel = .flash25
    @State private var ollamaModel: String = ""
    @State private var showAdvanced = false

    var body: some View {
        Form {
            Section {
                Picker("Wer poliert deinen Text? (LLM)", selection: $globalKind) {
                    ForEach(ProviderKind.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: globalKind) { _, _ in writeGlobal() }

                Group {
                    switch globalKind {
                    case .anthropic: AnthropicProviderRow(model: $anthropicModel) { writeGlobal() }
                    case .openAI:    OpenAIProviderRow(model: $openAIModel) { writeGlobal() }
                    case .google:    GoogleProviderRow(model: $googleModel) { writeGlobal() }
                    case .ollama:    OllamaSection(modelID: $ollamaModel) { writeGlobal() }
                    case .apple, .none: EmptyView()
                    }
                }
            } header: {
                Text("Standard für alle Modi")
            }

            Section {
                DisclosureGroup("Erweitert: Pro Modus überschreiben", isExpanded: $showAdvanced) {
                    ForEach(DictationMode.allCases) { mode in
                        ModeOverrideRow(mode: mode, settings: settings)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { loadFromSettings() }
    }

    private func loadFromSettings() {
        let choice = settings.globalLLMChoice
        globalKind = choice.kind
        switch choice {
        case .anthropic(let m): anthropicModel = m
        case .openAI(let m):    openAIModel = m
        case .google(let m):    googleModel = m
        case .ollama(let id):   ollamaModel = id
        default: break
        }
    }

    private func writeGlobal() {
        let new: LLMChoice
        switch globalKind {
        case .none:      new = .none
        case .apple:     new = .appleFoundationModels
        case .anthropic: new = .anthropic(anthropicModel)
        case .openAI:    new = .openAI(openAIModel)
        case .google:    new = .google(googleModel)
        case .ollama:    new = .ollama(modelID: ollamaModel)
        }
        settings.globalLLMChoice = new
    }
}

private struct ModeOverrideRow: View {
    let mode: DictationMode
    @Bindable var settings: SettingsStore
    @State private var useGlobal: Bool = true

    var body: some View {
        HStack {
            Text(mode.displayName)
            Spacer()
            // Vereinfachte Override-UI: nur Toggle „nutzt Standard" — vollständige
            // Sub-Picker pro Modus folgen, wenn User es braucht.
            Toggle("Standard", isOn: $useGlobal)
                .onChange(of: useGlobal) { _, on in
                    if on { settings.setOverride(nil, for: mode) }
                }
        }
        .task {
            useGlobal = settings.override(for: mode) == nil
        }
    }
}

#Preview { EnginesTab().frame(width: 640, height: 520) }

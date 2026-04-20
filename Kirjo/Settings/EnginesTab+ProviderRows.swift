import SwiftUI
import KirjoCore
import KirjoPostProcessing

struct AnthropicProviderRow: View {
    @Binding var model: AnthropicModel
    @State private var apiKey: String = ""
    @State private var testStatus: TestStatus = .idle
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Modell", selection: $model) {
                ForEach(AnthropicModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .onChange(of: model) { _, _ in onChange() }

            HStack {
                SecureField("API-Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Button("Testen") { testKey() }
                    .disabled(apiKey.isEmpty)
            }
            testStatus.label
        }
        .task {
            apiKey = KeychainStore.key(for: .anthropic) ?? ""
        }
        .onChange(of: apiKey) { _, new in
            KeychainStore.setKey(new.isEmpty ? nil : new, for: .anthropic)
        }
    }

    private func testKey() {
        testStatus = .checking
        let chosen = model
        let key = apiKey
        Task {
            let engine = AnthropicEngine(model: chosen, apiKey: key)
            do {
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
                await MainActor.run { testStatus = .ok }
            } catch let err as LLMError {
                await MainActor.run { testStatus = .fail(err.userFacingMessage) }
            } catch {
                await MainActor.run { testStatus = .fail("Unbekannter Fehler") }
            }
        }
    }
}

struct OpenAIProviderRow: View {
    @Binding var model: OpenAIModel
    @State private var apiKey: String = ""
    @State private var testStatus: TestStatus = .idle
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Modell", selection: $model) {
                ForEach(OpenAIModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .onChange(of: model) { _, _ in onChange() }

            HStack {
                SecureField("API-Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Button("Testen") { testKey() }
                    .disabled(apiKey.isEmpty)
            }
            testStatus.label
        }
        .task { apiKey = KeychainStore.key(for: .openAI) ?? "" }
        .onChange(of: apiKey) { _, new in
            KeychainStore.setKey(new.isEmpty ? nil : new, for: .openAI)
        }
    }

    private func testKey() {
        testStatus = .checking
        let chosen = model
        let key = apiKey
        Task {
            let engine = OpenAIEngine(model: chosen, apiKey: key)
            do {
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
                await MainActor.run { testStatus = .ok }
            } catch let err as LLMError {
                await MainActor.run { testStatus = .fail(err.userFacingMessage) }
            } catch {
                await MainActor.run { testStatus = .fail("Unbekannter Fehler") }
            }
        }
    }
}

struct GoogleProviderRow: View {
    @Binding var model: GoogleModel
    @State private var apiKey: String = ""
    @State private var testStatus: TestStatus = .idle
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Modell", selection: $model) {
                ForEach(GoogleModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .onChange(of: model) { _, _ in onChange() }

            HStack {
                SecureField("API-Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Button("Testen") { testKey() }
                    .disabled(apiKey.isEmpty)
            }
            testStatus.label
        }
        .task { apiKey = KeychainStore.key(for: .google) ?? "" }
        .onChange(of: apiKey) { _, new in
            KeychainStore.setKey(new.isEmpty ? nil : new, for: .google)
        }
    }

    private func testKey() {
        testStatus = .checking
        let chosen = model
        let key = apiKey
        Task {
            let engine = GoogleEngine(model: chosen, apiKey: key)
            do {
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
                await MainActor.run { testStatus = .ok }
            } catch let err as LLMError {
                await MainActor.run { testStatus = .fail(err.userFacingMessage) }
            } catch {
                await MainActor.run { testStatus = .fail("Unbekannter Fehler") }
            }
        }
    }
}

enum TestStatus {
    case idle, checking, ok, fail(String)

    @ViewBuilder var label: some View {
        switch self {
        case .idle: EmptyView()
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Teste …") }
                .foregroundStyle(.secondary).font(.footnote)
        case .ok:
            Label("Schlüssel gültig", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.footnote)
        case .fail(let msg):
            Label(msg, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red).font(.footnote)
        }
    }
}

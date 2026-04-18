import Foundation
import NotikaCore
import os

public final class OllamaEngine: PostProcessingEngine {
    public let id: PostProcessingEngineID = .ollama

    private let modelID: String
    private let baseURL: URL
    private let client: LLMHTTPClient
    private let logger = Logger(subsystem: "com.notika.mac", category: "PostProcessing.Ollama")

    public init(modelID: String,
                baseURL: URL = URL(string: "http://localhost:11434")!,
                httpClient: LLMHTTPClient = LLMHTTPClient()) {
        self.modelID = modelID
        self.baseURL = baseURL
        self.client = httpClient
    }

    private struct ChatRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        struct Usage: Decodable {
            let prompt_tokens: Int
            let completion_tokens: Int
        }
        let model: String
        let choices: [Choice]
        let usage: Usage?
    }

    public func process(transcript: String, mode: DictationMode, language: Language) async throws -> ProcessedText {
        guard !transcript.isEmpty else {
            return ProcessedText(text: transcript, provider: .ollama, model: modelID)
        }
        let systemPrompt = PromptStore.effectivePrompt(for: mode)
            + "\n\nAntworte in der Sprache des Eingabetextes (Deutsch oder Englisch)."

        let body = ChatRequest(
            model: modelID,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: transcript)
            ],
            temperature: temperature(for: mode),
            max_tokens: 1024
        )

        var req = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        logger.info("→ Ollama \(self.modelID, privacy: .public), \(transcript.count) chars")
        let data: Data
        do {
            data = try await client.send(req)
        } catch let err as LLMError {
            // Wenn der Server nicht erreichbar ist oder hängt, mappen wir auf .ollamaUnavailable
            if case .network = err { throw LLMError.ollamaUnavailable }
            if case .timeout = err { throw LLMError.ollamaUnavailable }
            throw err
        }

        let decoded: ChatResponse
        do {
            decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            logger.error("Decode-Fehler: \(error.localizedDescription, privacy: .public)")
            throw LLMError.invalidResponse
        }
        let text = decoded.choices.first?.message.content ?? ""
        return ProcessedText(
            text: text,
            costUSD: nil,                                  // lokal = 0 USD
            tokensIn: decoded.usage?.prompt_tokens,
            tokensOut: decoded.usage?.completion_tokens,
            provider: .ollama,
            model: decoded.model
        )
    }

    private func temperature(for mode: DictationMode) -> Double {
        switch mode {
        case .literal: return 0.05
        case .social:  return 0.6
        case .formal:  return 0.2
        }
    }
}

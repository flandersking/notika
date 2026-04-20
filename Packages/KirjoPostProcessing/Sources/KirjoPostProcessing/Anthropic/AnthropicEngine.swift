import Foundation
import KirjoCore
import os

public final class AnthropicEngine: PostProcessingEngine {
    public let id: PostProcessingEngineID = .anthropic

    private let model: AnthropicModel
    private let apiKey: String
    private let client: LLMHTTPClient
    private let logger = Logger(subsystem: "com.notika.mac", category: "PostProcessing.Anthropic")

    public init(model: AnthropicModel, apiKey: String, httpClient: LLMHTTPClient = LLMHTTPClient()) {
        self.model = model
        self.apiKey = apiKey
        self.client = httpClient
    }

    public func process(transcript: String, mode: DictationMode, language: Language) async throws -> ProcessedText {
        guard !transcript.isEmpty else {
            return ProcessedText(text: transcript, provider: .anthropic, model: model.rawValue)
        }
        let systemPrompt = PromptStore.effectivePrompt(for: mode)
            + "\n\nAntworte in der Sprache des Eingabetextes (Deutsch oder Englisch)."

        let body = AnthropicRequest(
            model: model.rawValue,
            max_tokens: 1024,
            temperature: temperature(for: mode),
            system: systemPrompt,
            messages: [.init(role: "user", content: transcript)]
        )

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONEncoder().encode(body)

        logger.info("→ Anthropic \(self.model.rawValue, privacy: .public), \(transcript.count) chars")
        let data = try await client.send(req)

        let decoded: AnthropicResponse
        do {
            decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        } catch {
            logger.error("Decode-Fehler: \(error.localizedDescription, privacy: .public)")
            throw LLMError.invalidResponse
        }
        let cost = CostCalculator.cost(modelID: model.rawValue, tokensIn: decoded.usage.input_tokens, tokensOut: decoded.usage.output_tokens)
        logger.info("← Anthropic OK, in=\(decoded.usage.input_tokens) out=\(decoded.usage.output_tokens) cost=\(cost ?? 0)")
        return ProcessedText(
            text: decoded.firstText,
            costUSD: cost,
            tokensIn: decoded.usage.input_tokens,
            tokensOut: decoded.usage.output_tokens,
            provider: .anthropic,
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

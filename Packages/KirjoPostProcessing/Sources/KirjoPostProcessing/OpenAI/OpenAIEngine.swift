import Foundation
import KirjoCore
import os

public final class OpenAIEngine: PostProcessingEngine {
    public let id: PostProcessingEngineID = .openAI

    private let model: OpenAIModel
    private let apiKey: String
    private let client: LLMHTTPClient
    private let logger = Logger(subsystem: "de.dymny.kirjo.mac", category: "PostProcessing.OpenAI")

    public init(model: OpenAIModel, apiKey: String, httpClient: LLMHTTPClient = LLMHTTPClient()) {
        self.model = model
        self.apiKey = apiKey
        self.client = httpClient
    }

    public func process(transcript: String, mode: DictationMode, language: Language) async throws -> ProcessedText {
        guard !transcript.isEmpty else {
            return ProcessedText(text: transcript, provider: .openAI, model: model.rawValue)
        }
        let instructions = PromptStore.effectivePrompt(for: mode)
            + "\n\nAntworte in der Sprache des Eingabetextes (Deutsch oder Englisch)."

        let body = OpenAIRequest(
            model: model.rawValue,
            instructions: instructions,
            input: transcript,
            temperature: temperature(for: mode),
            max_output_tokens: 1024
        )

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)

        logger.info("→ OpenAI \(self.model.rawValue, privacy: .public), \(transcript.count) chars")
        let data = try await client.send(req)

        let decoded: OpenAIResponse
        do {
            decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            logger.error("Decode-Fehler: \(error.localizedDescription, privacy: .public)")
            throw LLMError.invalidResponse
        }
        let cost = CostCalculator.cost(modelID: model.rawValue, tokensIn: decoded.usage.input_tokens, tokensOut: decoded.usage.output_tokens)
        logger.info("← OpenAI OK, in=\(decoded.usage.input_tokens) out=\(decoded.usage.output_tokens) cost=\(cost ?? 0)")
        return ProcessedText(
            text: decoded.firstText,
            costUSD: cost,
            tokensIn: decoded.usage.input_tokens,
            tokensOut: decoded.usage.output_tokens,
            provider: .openAI,
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

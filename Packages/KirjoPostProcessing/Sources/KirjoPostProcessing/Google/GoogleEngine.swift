import Foundation
import NotikaCore
import os

public final class GoogleEngine: PostProcessingEngine {
    public let id: PostProcessingEngineID = .google

    private let model: GoogleModel
    private let apiKey: String
    private let client: LLMHTTPClient
    private let logger = Logger(subsystem: "com.notika.mac", category: "PostProcessing.Google")

    public init(model: GoogleModel, apiKey: String, httpClient: LLMHTTPClient = LLMHTTPClient()) {
        self.model = model
        self.apiKey = apiKey
        self.client = httpClient
    }

    public func process(transcript: String, mode: DictationMode, language: Language) async throws -> ProcessedText {
        guard !transcript.isEmpty else {
            return ProcessedText(text: transcript, provider: .google, model: model.rawValue)
        }
        let systemPrompt = PromptStore.effectivePrompt(for: mode)
            + "\n\nAntworte in der Sprache des Eingabetextes (Deutsch oder Englisch)."

        let body = GoogleRequest(
            contents: [.init(parts: [.init(text: transcript)], role: "user")],
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            generationConfig: .init(temperature: temperature(for: mode), maxOutputTokens: 1024)
        )

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent"
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.httpBody = try JSONEncoder().encode(body)

        logger.info("→ Google \(self.model.rawValue, privacy: .public), \(transcript.count) chars")
        let data = try await client.send(req)

        let decoded: GoogleResponse
        do {
            decoded = try JSONDecoder().decode(GoogleResponse.self, from: data)
        } catch {
            logger.error("Decode-Fehler: \(error.localizedDescription, privacy: .public)")
            throw LLMError.invalidResponse
        }
        let cost = CostCalculator.cost(modelID: model.rawValue, tokensIn: decoded.usageMetadata.promptTokenCount, tokensOut: decoded.usageMetadata.candidatesTokenCount)
        logger.info("← Google OK, in=\(decoded.usageMetadata.promptTokenCount) out=\(decoded.usageMetadata.candidatesTokenCount) cost=\(cost ?? 0)")
        return ProcessedText(
            text: decoded.firstText,
            costUSD: cost,
            tokensIn: decoded.usageMetadata.promptTokenCount,
            tokensOut: decoded.usageMetadata.candidatesTokenCount,
            provider: .google,
            model: decoded.modelVersion ?? model.rawValue
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

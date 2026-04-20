import Foundation
import NotikaCore

/// Preise pro 1 Million Tokens in USD.
/// Quelle: Provider-Doku, Stand 2026-04-18.
/// Vor Release verifizieren auf docs.anthropic.com/pricing,
/// openai.com/api/pricing/, ai.google.dev/gemini-api/docs/pricing.
public enum PricingTable {
    public struct Entry: Sendable, Equatable {
        public let inputUSDPerMillion: Double
        public let outputUSDPerMillion: Double
    }

    public static let entries: [String: Entry] = [
        // Anthropic
        "claude-haiku-4-5":  Entry(inputUSDPerMillion: 1.00,  outputUSDPerMillion: 5.00),
        "claude-sonnet-4-6": Entry(inputUSDPerMillion: 3.00,  outputUSDPerMillion: 15.00),
        "claude-opus-4-7":   Entry(inputUSDPerMillion: 5.00,  outputUSDPerMillion: 25.00),
        // OpenAI
        "gpt-5.4-nano":      Entry(inputUSDPerMillion: 0.20,  outputUSDPerMillion: 1.25),
        "gpt-5.4-mini":      Entry(inputUSDPerMillion: 0.75,  outputUSDPerMillion: 4.50),
        "gpt-5.4":           Entry(inputUSDPerMillion: 2.50,  outputUSDPerMillion: 15.00),
        // Google
        "gemini-3.1-flash-lite-preview": Entry(inputUSDPerMillion: 0.25, outputUSDPerMillion: 1.50),
        "gemini-2.5-flash":              Entry(inputUSDPerMillion: 0.30, outputUSDPerMillion: 2.50),
        "gemini-3.1-pro-preview":        Entry(inputUSDPerMillion: 2.00, outputUSDPerMillion: 12.00),
    ]

    public static func entry(for modelID: String) -> Entry? {
        entries[modelID]
    }
}

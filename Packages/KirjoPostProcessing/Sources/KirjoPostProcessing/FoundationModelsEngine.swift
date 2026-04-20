import Foundation
import FoundationModels
import KirjoCore
import os

/// Post-Processing-Engine, die das Apple Foundation Models Framework nutzt
/// (on-device LLM, verfügbar ab macOS 26). Liest die Modus-Prompts aus den
/// Package-Ressourcen und fordert für jeden Modus eine aufbereitete Version
/// des Transkripts an.
public final class FoundationModelsEngine: PostProcessingEngine {
    public let id: PostProcessingEngineID = .appleFoundationModels

    private let logger = Logger(subsystem: "de.dymny.kirjo.mac", category: "PostProcessing.Apple")
    private let model = SystemLanguageModel.default

    public init() {}

    public func process(
        transcript: String,
        mode: DictationMode,
        language: Language
    ) async throws -> ProcessedText {
        guard !transcript.isEmpty else {
            return ProcessedText(text: transcript, provider: .appleFoundationModels)
        }

        guard model.isAvailable else {
            logger.warning("SystemLanguageModel nicht verfügbar — gebe Transkript unverändert zurück")
            return ProcessedText(text: transcript, provider: .appleFoundationModels)
        }

        let instructions = try loadInstructions(for: mode, language: language)

        let session = LanguageModelSession(instructions: instructions)

        let userPrompt = buildUserPrompt(transcript: transcript, language: language)
        logger.info("Starte LLM-Post-Processing (mode: \(mode.shortName, privacy: .public), \(transcript.count) chars)")

        let response = try await session.respond(
            to: userPrompt,
            options: GenerationOptions(temperature: mode.temperature)
        )

        let raw = response.content
        let cleaned = Self.stripPreambleAndQuotes(raw)
        logger.info("LLM-Output roh: \(raw, privacy: .public)")
        logger.info("LLM-Output final: \(cleaned, privacy: .public)")
        let final = cleaned.isEmpty ? transcript : cleaned
        return ProcessedText(
            text: final,
            costUSD: nil,
            tokensIn: nil,
            tokensOut: nil,
            provider: .appleFoundationModels,
            model: nil
        )
    }

    // MARK: - Post-Filter

    /// Entfernt typische Meta-Präambeln und umschließende Anführungszeichen,
    /// die kleinere on-device LLMs manchmal produzieren, obwohl die Prompt
    /// das verbietet.
    static func stripPreambleAndQuotes(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Typische Präambel-Zeilen entfernen (deutsch + englisch).
        let preamblePatterns = [
            #"^(hier (ist|kommt|sind)( der| die| das)?[^:]*:)\s*"#,
            #"^(korrigiert(er)?( satz| text| version)?:)\s*"#,
            #"^(here (is|are|comes|you go)( the)?[^:]*:)\s*"#,
            #"^(corrected( text| version| sentence)?:)\s*"#,
            #"^(ergebnis:|result:|output:)\s*"#
        ]
        for pattern in preamblePatterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                text.removeSubrange(range)
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Markdown-Code-Blöcke ausziehen (```...```).
        if text.hasPrefix("```"), let closeRange = text.range(of: "```", range: text.index(text.startIndex, offsetBy: 3)..<text.endIndex) {
            let inner = text.index(text.startIndex, offsetBy: 3)..<closeRange.lowerBound
            text = String(text[inner]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let newline = text.firstIndex(of: "\n") {
                // Optionale Sprach-Kennung überspringen (```text\nINHALT\n```).
                let firstLine = text[..<newline]
                if firstLine.count < 12, firstLine.allSatisfy({ $0.isLetter }) {
                    text = String(text[text.index(after: newline)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // Umschließende Anführungszeichen entfernen, wenn Anfang & Ende identisch.
        let quotePairs: [(Character, Character)] = [
            ("\"", "\""),
            ("„", "\u{201C}"), // „ … "
            ("„", "\u{201D}"), // „ … "
            ("\u{201C}", "\u{201D}"),
            ("'", "'"),
            ("‚", "\u{2018}"),
            ("«", "»")
        ]
        for (open, close) in quotePairs {
            if text.count > 1, text.first == open, text.last == close {
                text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        return text
    }

    // MARK: - Prompt-Loading

    private func loadInstructions(
        for mode: DictationMode,
        language: Language
    ) throws -> String {
        let base = PromptStore.effectivePrompt(for: mode)
        let languageHint = "\n\nAntworte in der Sprache des Eingabetextes (Deutsch oder Englisch). Der Nutzer diktiert aktuell primär in \(language == .german ? "Deutsch" : "Englisch")."
        return base + languageHint
    }

    private func buildUserPrompt(transcript: String, language: Language) -> String {
        """
        Hier ist das Transkript, das du bearbeiten sollst:

        """ + transcript
    }
}

private extension DictationMode {
    var temperature: Double {
        switch self {
        case .literal: return 0.05
        case .social:  return 0.5
        case .formal:  return 0.1
        }
    }
}

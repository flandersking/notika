import Foundation
import KirjoCore

/// Protokoll für STT-Engines, um Hints (Custom-Vocab) pro Sprache abzufragen.
/// Phase 1a eingeführt, Phase 1b-3 mit `DictionaryStore` erfüllt.
public protocol DictionaryStoring: AnyObject, Sendable {
    func hintsForLanguage(_ language: Language) -> [String]
}

import Foundation
import NotikaCore

// Stub für Phase 1a. Wird in Phase 1b mit SwiftData-Modell und CRUD befüllt.
public protocol DictionaryStoring: AnyObject, Sendable {
    func hintsForLanguage(_ language: Language) -> [String]
}

public final class InMemoryDictionaryStore: DictionaryStoring, @unchecked Sendable {
    public init() {}
    public func hintsForLanguage(_ language: Language) -> [String] { [] }
}

import Foundation
import KirjoCore

/// Thread-safer Snapshot-Cache für STT-Engines (nonisolated-Access möglich).
/// Wird vom DictionaryStore bei Änderungen aktualisiert.
public final class DictionaryHintsCache: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: [String: [String]] = [:]   // key = Language.rawValue

    public static let shared = DictionaryHintsCache()

    public init() {}

    public func update(_ hints: [String: [String]]) {
        lock.withLock { snapshot = hints }
    }

    public func hints(for language: Language) -> [String] {
        lock.withLock { snapshot[language.rawValue] ?? [] }
    }
}

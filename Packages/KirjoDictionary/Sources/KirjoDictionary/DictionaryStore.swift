import Foundation
import SwiftData
import NotikaCore

/// Phase 1b-3: SwiftData-basierter DictionaryStore. Erfüllt das `DictionaryStoring`-Protokoll
/// aus Phase 1a über einen nonisolated-Cache.
@MainActor
public final class DictionaryStore: DictionaryStoring {
    public let container: ModelContainer
    private let context: ModelContext
    private let hintsCache: DictionaryHintsCache

    public static let hintsLimitPerLanguage = 100

    /// Production-Init mit persistentem Container.
    public init() {
        let schema = Schema([DictionaryTerm.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        self.container = try! ModelContainer(for: schema, configurations: [config])
        self.context = ModelContext(self.container)
        self.hintsCache = DictionaryHintsCache.shared
        refreshCache()
    }

    /// Test-Init mit injiziertem Container (typisch In-Memory).
    public init(container: ModelContainer, hintsCache: DictionaryHintsCache = DictionaryHintsCache()) {
        self.container = container
        self.context = ModelContext(container)
        self.hintsCache = hintsCache
        refreshCache()
    }

    // MARK: - CRUD

    public func addTerm(_ term: String, language: Language, category: DictionaryCategory) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = DictionaryTerm(term: trimmed, language: language, category: category)
        context.insert(entry)
        try? context.save()
        refreshCache()
    }

    public func updateTerm(_ entry: DictionaryTerm, newTerm: String, newLanguage: Language, newCategory: DictionaryCategory) {
        let trimmed = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entry.term = trimmed
        entry.languageRawValue = newLanguage.rawValue
        entry.categoryRawValue = newCategory.rawValue
        entry.updatedAt = Date()
        try? context.save()
        refreshCache()
    }

    public func deleteTerm(_ entry: DictionaryTerm) {
        context.delete(entry)
        try? context.save()
        refreshCache()
    }

    public func deleteAll() {
        for entry in allTerms() {
            context.delete(entry)
        }
        try? context.save()
        refreshCache()
    }

    // MARK: - Query

    public func allTerms() -> [DictionaryTerm] {
        let descriptor = FetchDescriptor<DictionaryTerm>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func terms(language: Language?) -> [DictionaryTerm] {
        guard let language else { return allTerms() }
        return allTerms().filter { $0.languageRawValue == language.rawValue }
    }

    public func terms(category: DictionaryCategory?) -> [DictionaryTerm] {
        guard let category else { return allTerms() }
        return allTerms().filter { $0.categoryRawValue == category.rawValue }
    }

    // MARK: - Cache-Sync

    private func refreshCache() {
        let all = allTerms()
        var grouped: [String: [String]] = [:]
        for term in all {
            let key = term.languageRawValue
            var list = grouped[key] ?? []
            if list.count < Self.hintsLimitPerLanguage {
                list.append(term.term)
            }
            grouped[key] = list
        }
        hintsCache.update(grouped)
    }

    // MARK: - DictionaryStoring-Protokoll

    public nonisolated func hintsForLanguage(_ language: Language) -> [String] {
        hintsCache.hints(for: language)
    }

    // MARK: - CSV I/O (Convenience — Delegate an DictionaryCSV)

    public func exportCSV(to url: URL) throws {
        try DictionaryCSV.export(terms: allTerms(), to: url)
    }

    public func importCSV(from url: URL) throws -> (imported: Int, skipped: Int) {
        let rows = try DictionaryCSV.importRows(from: url)
        var imported = 0
        var skipped = 0
        for row in rows {
            switch row {
            case .ok(let term, let language, let category):
                addTerm(term, language: language, category: category)
                imported += 1
            case .skip:
                skipped += 1
            }
        }
        return (imported, skipped)
    }
}

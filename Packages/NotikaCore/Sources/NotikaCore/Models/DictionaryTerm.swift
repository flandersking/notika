import Foundation
import SwiftData

@Model
public final class DictionaryTerm {
    public var term: String
    public var languageRawValue: String
    public var categoryRawValue: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(term: String, language: Language, category: DictionaryCategory) {
        self.term = term
        self.languageRawValue = language.rawValue
        self.categoryRawValue = category.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var language: Language? {
        Language(rawValue: languageRawValue)
    }

    public var category: DictionaryCategory? {
        DictionaryCategory(rawValue: categoryRawValue)
    }
}

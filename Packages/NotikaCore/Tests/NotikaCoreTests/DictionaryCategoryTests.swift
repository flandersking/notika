import XCTest
@testable import NotikaCore

final class DictionaryCategoryTests: XCTestCase {
    func test_allCases_displayName_nonEmpty() {
        for category in DictionaryCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty, "\(category.rawValue) braucht displayName")
        }
    }

    func test_displayName_medical_isDeutsch() {
        XCTAssertEqual(DictionaryCategory.medical.displayName, "Medizin")
    }

    func test_fiveCategories() {
        XCTAssertEqual(DictionaryCategory.allCases.count, 5)
    }

    func test_codable_roundtrip() throws {
        let original = DictionaryCategory.technical
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DictionaryCategory.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

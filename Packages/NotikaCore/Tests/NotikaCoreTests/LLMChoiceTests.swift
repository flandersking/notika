import XCTest
@testable import NotikaCore

final class LLMChoiceTests: XCTestCase {
    func test_anthropicHaiku_codable_roundtrip() throws {
        let original: LLMChoice = .anthropic(.haiku45)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_ollama_withModelID_codable_roundtrip() throws {
        let original: LLMChoice = .ollama(modelID: "llama3.2:latest")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_none_codable_roundtrip() throws {
        let original: LLMChoice = .none
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_displayName_anthropicHaiku() {
        XCTAssertEqual(LLMChoice.anthropic(.haiku45).displayName, "Claude Haiku 4.5 (schnell, günstig)")
    }
}

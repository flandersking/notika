import XCTest
@testable import KirjoCore

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

    // MARK: - effectiveChoice / Override

    @MainActor
    func test_effectiveChoice_withoutOverride_returnsGlobal() {
        let defaults = UserDefaults(suiteName: "test.kirjo.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.globalLLMChoice = .anthropic(.haiku45)
        XCTAssertEqual(store.effectiveChoice(for: .literal), .anthropic(.haiku45))
    }

    @MainActor
    func test_effectiveChoice_withOverride_returnsOverride() {
        let defaults = UserDefaults(suiteName: "test.kirjo.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.globalLLMChoice = .appleFoundationModels
        store.setOverride(.openAI(.mini54), for: .social)
        XCTAssertEqual(store.effectiveChoice(for: .social), .openAI(.mini54))
        XCTAssertEqual(store.effectiveChoice(for: .literal), .appleFoundationModels)
    }

    @MainActor
    func test_setOverride_nil_removesOverride() {
        let defaults = UserDefaults(suiteName: "test.kirjo.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.globalLLMChoice = .appleFoundationModels
        store.setOverride(.google(.flash25), for: .formal)
        store.setOverride(nil, for: .formal)
        XCTAssertEqual(store.effectiveChoice(for: .formal), .appleFoundationModels)
    }

    // MARK: - Migration vom Phase-1a-rawString-Format

    @MainActor
    func test_migration_rawAppleFoundationModels_to_codable() {
        let suiteName = "test.kirjo.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("appleFoundationModels", forKey: "kirjo.settings.llmChoice")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.globalLLMChoice, .appleFoundationModels)
        XCTAssertNil(defaults.string(forKey: "kirjo.settings.llmChoice"))
        XCTAssertNotNil(defaults.data(forKey: "kirjo.settings.globalLLMChoice"))
    }

    @MainActor
    func test_migration_isIdempotent() {
        let suiteName = "test.kirjo.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("none", forKey: "kirjo.settings.llmChoice")
        _ = SettingsStore(defaults: defaults)   // erster Init migriert
        _ = SettingsStore(defaults: defaults)   // zweiter Init darf nichts ändern
        let stored = try? JSONDecoder().decode(LLMChoice.self, from: defaults.data(forKey: "kirjo.settings.globalLLMChoice")!)
        XCTAssertEqual(stored, LLMChoice.none)
        XCTAssertNil(defaults.string(forKey: "kirjo.settings.llmChoice"))
    }

    // MARK: - Codable-Roundtrips für OpenAI / Google

    func test_openAI_mini54_codable_roundtrip() throws {
        let original: LLMChoice = .openAI(.mini54)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_google_flash25_codable_roundtrip() throws {
        let original: LLMChoice = .google(.flash25)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - providerID-Mapping vollständig

    func test_providerID_mapping_allCases() {
        XCTAssertEqual(LLMChoice.none.providerID, .none)
        XCTAssertEqual(LLMChoice.appleFoundationModels.providerID, .appleFoundationModels)
        XCTAssertEqual(LLMChoice.anthropic(.haiku45).providerID, .anthropic)
        XCTAssertEqual(LLMChoice.openAI(.mini54).providerID, .openAI)
        XCTAssertEqual(LLMChoice.google(.flash25).providerID, .google)
        XCTAssertEqual(LLMChoice.ollama(modelID: "llama3.2:latest").providerID, .ollama)
    }
}

import XCTest
@testable import NotikaCore

final class STTEngineChoiceTests: XCTestCase {
    func test_apple_codable_roundtrip() throws {
        let original: STTEngineChoice = .apple
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(STTEngineChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_whisper_turbo_codable_roundtrip() throws {
        let original: STTEngineChoice = .whisper(.turbo)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(STTEngineChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_displayName_apple() {
        XCTAssertEqual(STTEngineChoice.apple.displayName, "Apple SpeechAnalyzer")
    }

    func test_displayName_whisperTurbo_includesModelName() {
        XCTAssertTrue(STTEngineChoice.whisper(.turbo).displayName.contains("Turbo"))
    }

    func test_whisperModelID_allCases_haveSize() {
        for model in WhisperModelID.allCases {
            XCTAssertGreaterThan(model.approximateBytes, 0, "\(model.rawValue) muss eine Größe haben")
        }
    }

    @MainActor
    func test_settingsStore_sttEngineChoice_defaults_to_apple() {
        let defaults = UserDefaults(suiteName: "test.notika.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.sttEngineChoice, .apple)
    }

    @MainActor
    func test_settingsStore_sttEngineChoice_persists_whisperTurbo() {
        let defaults = UserDefaults(suiteName: "test.notika.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.sttEngineChoice = .whisper(.turbo)
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.sttEngineChoice, .whisper(.turbo))
    }
}

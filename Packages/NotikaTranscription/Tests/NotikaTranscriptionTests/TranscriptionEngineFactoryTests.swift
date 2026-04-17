import XCTest
@testable import NotikaTranscription

final class TranscriptionEngineFactoryTests: XCTestCase {
    func testAppleSpeechAnalyzerIsAvailable() {
        XCTAssertTrue(TranscriptionEngineFactory.availableEngines().contains(.appleSpeechAnalyzer))
    }
}

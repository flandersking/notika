import XCTest
@testable import KirjoTranscription

final class TranscriptionEngineFactoryTests: XCTestCase {
    func testAppleSpeechAnalyzerIsAvailable() {
        XCTAssertTrue(TranscriptionEngineFactory.availableEngines().contains(.appleSpeechAnalyzer))
    }
}

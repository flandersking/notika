import XCTest
@testable import NotikaWhisper
import NotikaCore

final class WhisperErrorTests: XCTestCase {
    func test_modelNotInstalled_userFacingMessage_mentionsLaden() {
        let err = WhisperError.modelNotInstalled(.turbo)
        XCTAssertTrue(err.userFacingMessage.lowercased().contains("modell") ||
                      err.userFacingMessage.lowercased().contains("laden"))
    }

    func test_insufficientDiskSpace_userFacingMessage_mentionsSpeicher() {
        let err = WhisperError.insufficientDiskSpace(required: 1_500_000_000, available: 100_000_000)
        XCTAssertTrue(err.userFacingMessage.lowercased().contains("speicher"))
    }

    func test_description_doesNotLeakReason_for_downloadFailed() {
        let err = WhisperError.downloadFailed(reason: "Sensitive HTML body content xxx")
        XCTAssertFalse(err.description.contains("Sensitive HTML body content"))
        XCTAssertTrue(err.description.contains("downloadFailed"))
    }

    func test_description_doesNotLeakReason_for_transcriptionFailed() {
        let err = WhisperError.transcriptionFailed(reason: "very-long-internal-stack-trace")
        XCTAssertFalse(err.description.contains("very-long-internal-stack-trace"))
    }

    func test_description_for_modelNotInstalled_includesModelID() {
        let err = WhisperError.modelNotInstalled(.turbo)
        XCTAssertTrue(err.description.contains("turbo") || err.description.contains("Turbo"))
    }
}

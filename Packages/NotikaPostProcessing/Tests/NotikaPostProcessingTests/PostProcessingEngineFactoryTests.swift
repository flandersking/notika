import XCTest
@testable import NotikaPostProcessing

final class PostProcessingEngineFactoryTests: XCTestCase {
    func testFoundationModelsIsAvailable() {
        XCTAssertTrue(PostProcessingEngineFactory.availableEngines().contains(.appleFoundationModels))
    }
}

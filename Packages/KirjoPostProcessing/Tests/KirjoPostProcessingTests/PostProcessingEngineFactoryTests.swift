import XCTest
import KirjoCore
@testable import KirjoPostProcessing

final class PostProcessingEngineFactoryTests: XCTestCase {
    func testFoundationModelsEngineIsProduced() {
        XCTAssertNotNil(PostProcessingEngineFactory.makeEngine(for: .appleFoundationModels))
    }

    func testNoneChoiceProducesNoEngine() {
        XCTAssertNil(PostProcessingEngineFactory.makeEngine(for: .none))
    }
}

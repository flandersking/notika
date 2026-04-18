import XCTest
import NotikaCore
@testable import NotikaPostProcessing

final class PostProcessingEngineFactoryTests: XCTestCase {
    func testFoundationModelsEngineIsProduced() {
        XCTAssertNotNil(PostProcessingEngineFactory.makeEngine(for: .appleFoundationModels))
    }

    func testNoneChoiceProducesNoEngine() {
        XCTAssertNil(PostProcessingEngineFactory.makeEngine(for: .none))
    }
}

import XCTest
@testable import NotikaPostProcessing
import NotikaCore

final class AnthropicEngineTests: XCTestCase {
    var engine: AnthropicEngine!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = LLMHTTPClient(session: session, timeout: 1.0, retryDelay: 0)
        engine = AnthropicEngine(model: .haiku45, apiKey: "sk-ant-test", httpClient: client)
    }

    override func tearDown() { MockURLProtocol.reset(); super.tearDown() }

    func test_process_returns_processedText_with_cost() async throws {
        let url = Bundle.module.url(forResource: "anthropic-haiku-success", withExtension: "json", subdirectory: "Fixtures")!
        let fixtureData = try Data(contentsOf: url)
        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.absoluteString, "https://api.anthropic.com/v1/messages")
            XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test")
            XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, fixtureData)
        }
        let result = try await engine.process(transcript: "hallo wie geht es ihnen heute", mode: .formal, language: .german)
        XCTAssertEqual(result.text, "Hallo, wie geht es Ihnen heute?")
        XCTAssertEqual(result.tokensIn, 42)
        XCTAssertEqual(result.tokensOut, 11)
        XCTAssertEqual(result.provider, .anthropic)
        XCTAssertEqual(result.model, "claude-haiku-4-5")
        // 42 in × 1$/1M + 11 out × 5$/1M
        XCTAssertEqual(result.costUSD!, (42.0/1_000_000) + (5 * 11.0/1_000_000), accuracy: 0.0000001)
    }
}

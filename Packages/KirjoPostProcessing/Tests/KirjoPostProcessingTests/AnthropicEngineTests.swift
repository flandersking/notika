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

    func test_process_emptyTranscript_returnsEarly_withoutHTTPCall() async throws {
        var requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            requestCount += 1
            let resp = HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let result = try await engine.process(transcript: "", mode: .literal, language: .german)
        XCTAssertEqual(result.text, "")
        XCTAssertEqual(result.provider, .anthropic)
        XCTAssertEqual(result.model, "claude-haiku-4-5")
        XCTAssertNil(result.costUSD)
        XCTAssertNil(result.tokensIn)
        XCTAssertNil(result.tokensOut)
        XCTAssertEqual(requestCount, 0, "Empty-Transcript darf keinen HTTP-Call machen")
    }

    func test_process_malformedJSON_throws_invalidResponse() async {
        MockURLProtocol.requestHandler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("not json".utf8))
        }
        do {
            _ = try await engine.process(transcript: "hallo", mode: .literal, language: .german)
            XCTFail("should throw")
        } catch let err as LLMError {
            XCTAssertEqual(err, .invalidResponse)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}

import XCTest
@testable import NotikaPostProcessing
import NotikaCore

final class OpenAIEngineTests: XCTestCase {
    var engine: OpenAIEngine!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = LLMHTTPClient(session: session, timeout: 1.0, retryDelay: 0)
        engine = OpenAIEngine(model: .mini54, apiKey: "sk-test", httpClient: client)
    }

    override func tearDown() { MockURLProtocol.reset(); super.tearDown() }

    func test_process_returns_processedText_with_cost() async throws {
        let url = Bundle.module.url(forResource: "openai-mini-success", withExtension: "json", subdirectory: "Fixtures")!
        let fixtureData = try Data(contentsOf: url)
        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.absoluteString, "https://api.openai.com/v1/responses")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, fixtureData)
        }
        let result = try await engine.process(transcript: "hallo wie gehts", mode: .social, language: .german)
        XCTAssertEqual(result.text, "Hallo, wie geht es dir heute?")
        XCTAssertEqual(result.tokensIn, 38)
        XCTAssertEqual(result.tokensOut, 9)
        XCTAssertEqual(result.provider, .openAI)
        XCTAssertEqual(result.model, "gpt-5.4-mini")
        XCTAssertEqual(result.costUSD!, (38.0/1_000_000 * 0.75) + (9.0/1_000_000 * 4.5), accuracy: 0.0000001)
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
        XCTAssertEqual(result.provider, .openAI)
        XCTAssertEqual(result.model, "gpt-5.4-mini")
        XCTAssertNil(result.costUSD)
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

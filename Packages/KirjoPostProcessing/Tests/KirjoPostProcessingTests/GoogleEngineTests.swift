import XCTest
@testable import KirjoPostProcessing
import KirjoCore

final class GoogleEngineTests: XCTestCase {
    var engine: GoogleEngine!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = LLMHTTPClient(session: session, timeout: 1.0, retryDelay: 0)
        engine = GoogleEngine(model: .flash25, apiKey: "g-test", httpClient: client)
    }

    override func tearDown() { MockURLProtocol.reset(); super.tearDown() }

    func test_process_returns_processedText_with_cost() async throws {
        let url = Bundle.module.url(forResource: "google-flash-success", withExtension: "json", subdirectory: "Fixtures")!
        let fixtureData = try Data(contentsOf: url)
        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.absoluteString, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")
            XCTAssertEqual(req.value(forHTTPHeaderField: "x-goog-api-key"), "g-test")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, fixtureData)
        }
        let result = try await engine.process(transcript: "hallo", mode: .social, language: .german)
        XCTAssertEqual(result.text, "Hallo, wie geht es dir?")
        XCTAssertEqual(result.tokensIn, 30)
        XCTAssertEqual(result.tokensOut, 8)
        XCTAssertEqual(result.provider, .google)
        XCTAssertEqual(result.model, "gemini-2.5-flash")
        XCTAssertEqual(result.costUSD!, (30.0/1_000_000 * 0.30) + (8.0/1_000_000 * 2.50), accuracy: 0.0000001)
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
        XCTAssertEqual(result.provider, .google)
        XCTAssertEqual(result.model, "gemini-2.5-flash")
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

import XCTest
@testable import NotikaPostProcessing
import NotikaCore

final class OllamaEngineTests: XCTestCase {

    func test_modelDiscovery_returns_installed_models() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let url = Bundle.module.url(forResource: "ollama-tags", withExtension: "json", subdirectory: "Fixtures")!
        let fixtureData = try Data(contentsOf: url)
        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.absoluteString, "http://localhost:11434/api/tags")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, fixtureData)
        }
        let discovery = OllamaModelDiscovery(session: session)
        let models = try await discovery.installedModels()
        XCTAssertEqual(models, ["llama3.2:latest", "qwen2.5:7b"])
        MockURLProtocol.reset()
    }

    func test_modelDiscovery_throws_unavailable_when_server_down() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        MockURLProtocol.requestHandler = { _ in throw URLError(.cannotConnectToHost) }
        let discovery = OllamaModelDiscovery(session: session)
        do {
            _ = try await discovery.installedModels()
            XCTFail("should throw")
        } catch let err as LLMError {
            XCTAssertEqual(err, .ollamaUnavailable)
        } catch {
            XCTFail("wrong error: \(error)")
        }
        MockURLProtocol.reset()
    }

    func test_engine_process_returns_processedText_with_zero_cost() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = LLMHTTPClient(session: session, timeout: 1.0, retryDelay: 0)
        let url = Bundle.module.url(forResource: "ollama-chat-success", withExtension: "json", subdirectory: "Fixtures")!
        let fixtureData = try Data(contentsOf: url)
        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.absoluteString, "http://localhost:11434/v1/chat/completions")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, fixtureData)
        }
        let engine = OllamaEngine(modelID: "llama3.2:latest", httpClient: client)
        let result = try await engine.process(transcript: "hallo", mode: .literal, language: .german)
        XCTAssertEqual(result.text, "Hallo, wie geht es dir?")
        XCTAssertEqual(result.tokensIn, 22)
        XCTAssertEqual(result.tokensOut, 7)
        XCTAssertEqual(result.provider, .ollama)
        XCTAssertEqual(result.model, "llama3.2:latest")
        XCTAssertNil(result.costUSD)   // Ollama nicht in PricingTable
        MockURLProtocol.reset()
    }
}

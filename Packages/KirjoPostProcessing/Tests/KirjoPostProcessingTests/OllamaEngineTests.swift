import XCTest
@testable import KirjoPostProcessing
import KirjoCore

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

    func test_modelDiscovery_returns_installed_model_infos_with_sizes() async throws {
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
        let infos = try await discovery.installedModelInfos()
        XCTAssertEqual(infos.count, 2)
        XCTAssertEqual(infos[0], OllamaModelInfo(name: "llama3.2:latest", sizeBytes: 2_000_000_000))
        XCTAssertEqual(infos[1], OllamaModelInfo(name: "qwen2.5:7b", sizeBytes: 4_500_000_000))
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

    func test_process_emptyTranscript_returnsEarly_withoutHTTPCall() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = LLMHTTPClient(session: session, timeout: 1.0, retryDelay: 0)
        var requestCount = 0
        MockURLProtocol.requestHandler = { _ in
            requestCount += 1
            let resp = HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let engine = OllamaEngine(modelID: "llama3.2:latest", httpClient: client)
        let result = try await engine.process(transcript: "", mode: .literal, language: .german)
        XCTAssertEqual(result.text, "")
        XCTAssertEqual(result.provider, .ollama)
        XCTAssertEqual(result.model, "llama3.2:latest")
        XCTAssertNil(result.costUSD)
        XCTAssertEqual(requestCount, 0, "Empty-Transcript darf keinen HTTP-Call machen")
        MockURLProtocol.reset()
    }

    func test_process_malformedJSON_throws_invalidResponse() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = LLMHTTPClient(session: session, timeout: 1.0, retryDelay: 0)
        MockURLProtocol.requestHandler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("not json".utf8))
        }
        let engine = OllamaEngine(modelID: "llama3.2:latest", httpClient: client)
        do {
            _ = try await engine.process(transcript: "hallo", mode: .literal, language: .german)
            XCTFail("should throw")
        } catch let err as LLMError {
            XCTAssertEqual(err, .invalidResponse)
        } catch {
            XCTFail("wrong error: \(error)")
        }
        MockURLProtocol.reset()
    }
}

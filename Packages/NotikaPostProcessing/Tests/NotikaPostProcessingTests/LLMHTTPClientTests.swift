import XCTest
@testable import NotikaPostProcessing

final class LLMHTTPClientTests: XCTestCase {
    var client: LLMHTTPClient!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        client = LLMHTTPClient(session: session, timeout: 1.0)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func test_send_returns_data_on_200() async throws {
        MockURLProtocol.requestHandler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("ok".utf8))
        }
        var req = URLRequest(url: URL(string: "https://example.com/x")!)
        req.httpMethod = "POST"
        let data = try await client.send(req)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "ok")
    }

    func test_send_returns_invalidKey_on_401() async {
        MockURLProtocol.requestHandler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data("unauthorized".utf8))
        }
        let req = URLRequest(url: URL(string: "https://example.com/x")!)
        do {
            _ = try await client.send(req)
            XCTFail("should throw")
        } catch let error as LLMError {
            XCTAssertEqual(error, .invalidKey)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_send_retries_once_on_network_error_then_succeeds() async throws {
        let attempts = AttemptCounter()
        MockURLProtocol.requestHandler = { req in
            let n = attempts.increment()
            if n == 1 {
                throw URLError(.notConnectedToInternet)
            }
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("retry-ok".utf8))
        }
        var req = URLRequest(url: URL(string: "https://example.com/x")!)
        req.httpMethod = "POST"
        let data = try await client.send(req)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "retry-ok")
        XCTAssertEqual(attempts.value, 2)
    }

    func test_send_does_not_retry_on_invalidKey() async {
        let attempts = AttemptCounter()
        MockURLProtocol.requestHandler = { req in
            _ = attempts.increment()
            let resp = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let req = URLRequest(url: URL(string: "https://example.com/x")!)
        do { _ = try await client.send(req) } catch {}
        XCTAssertEqual(attempts.value, 1)
    }
}

final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int { lock.withLock { _value } }
    @discardableResult
    func increment() -> Int { lock.withLock { _value += 1; return _value } }
}

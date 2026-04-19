import Foundation
import os

public final class LLMHTTPClient: Sendable {
    private let session: URLSession
    private let timeout: TimeInterval
    private let retryDelay: TimeInterval
    private let logger = Logger(subsystem: "com.notika.mac", category: "PostProcessing.HTTP")

    public init(session: URLSession = .shared, timeout: TimeInterval = 5, retryDelay: TimeInterval = 1) {
        self.session = session
        self.timeout = timeout
        self.retryDelay = retryDelay
    }

    public func send(_ request: URLRequest) async throws -> Data {
        do {
            return try await sendOnce(request)
        } catch LLMError.network, LLMError.timeout {
            logger.info("Retry nach Netzwerk-/Timeout-Fehler")
            try? await Task.sleep(for: .seconds(retryDelay))
            return try await sendOnce(request)
        }
    }

    private func sendOnce(_ request: URLRequest) async throws -> Data {
        var req = request
        req.timeoutInterval = timeout
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:                  throw LLMError.timeout
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotConnectToHost,
                 .cannotFindHost:            throw LLMError.network
            default:                          throw LLMError.network
            }
        } catch {
            throw LLMError.network
        }
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            throw LLMError.invalidKey
        case 404:
            let body = String(decoding: data, as: UTF8.self)
            throw LLMError.modelNotFound(body)
        case 429:
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After") as NSString?)?.doubleValue
            throw LLMError.rateLimit(retryAfter: retryAfter)
        default:
            let body = String(decoding: data, as: UTF8.self)
            throw LLMError.serverError(status: http.statusCode, body: String(body.prefix(500)))
        }
    }
}

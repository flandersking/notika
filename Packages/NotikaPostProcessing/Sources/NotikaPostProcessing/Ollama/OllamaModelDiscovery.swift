import Foundation

public final class OllamaModelDiscovery: Sendable {
    private let session: URLSession
    private let baseURL: URL

    public init(session: URLSession = .shared,
                baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.session = session
        self.baseURL = baseURL
    }

    private struct TagsResponse: Decodable {
        struct Model: Decodable { let name: String }
        let models: [Model]
    }

    public func installedModels() async throws -> [String] {
        let url = baseURL.appendingPathComponent("api/tags")
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw LLMError.ollamaUnavailable
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LLMError.ollamaUnavailable
        }
        do {
            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            return decoded.models.map(\.name)
        } catch {
            throw LLMError.invalidResponse
        }
    }
}

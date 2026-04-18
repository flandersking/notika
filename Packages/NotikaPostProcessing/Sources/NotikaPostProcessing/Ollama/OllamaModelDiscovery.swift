import Foundation

public struct OllamaModelInfo: Sendable, Hashable {
    public let name: String
    public let sizeBytes: Int64

    public init(name: String, sizeBytes: Int64) {
        self.name = name
        self.sizeBytes = sizeBytes
    }
}

public final class OllamaModelDiscovery: Sendable {
    private let session: URLSession
    private let baseURL: URL

    public init(session: URLSession = .shared,
                baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.session = session
        self.baseURL = baseURL
    }

    private struct TagsResponse: Decodable {
        struct Model: Decodable {
            let name: String
            let size: Int64
        }
        let models: [Model]
    }

    /// Lädt installierte Ollama-Modelle inkl. Größe in Bytes.
    public func installedModelInfos() async throws -> [OllamaModelInfo] {
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
            return decoded.models.map { OllamaModelInfo(name: $0.name, sizeBytes: $0.size) }
        } catch {
            throw LLMError.invalidResponse
        }
    }

    /// Convenience: nur die Modellnamen (ohne Größe).
    public func installedModels() async throws -> [String] {
        try await installedModelInfos().map(\.name)
    }
}

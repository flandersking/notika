import Foundation

struct GoogleResponse: Decodable {
    struct Part: Decodable { let text: String? }
    struct Content: Decodable { let parts: [Part] }
    struct Candidate: Decodable {
        let content: Content
    }
    struct UsageMetadata: Decodable {
        let promptTokenCount: Int
        let candidatesTokenCount: Int
    }
    let candidates: [Candidate]
    let usageMetadata: UsageMetadata
    let modelVersion: String?

    var firstText: String {
        candidates.first?.content.parts.first?.text ?? ""
    }
}

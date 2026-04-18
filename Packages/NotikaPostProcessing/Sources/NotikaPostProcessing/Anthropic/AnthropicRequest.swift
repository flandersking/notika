import Foundation

struct AnthropicRequest: Encodable {
    struct Message: Encodable {
        let role: String   // "user"
        let content: String
    }

    let model: String
    let max_tokens: Int
    let temperature: Double
    let system: String
    let messages: [Message]
}

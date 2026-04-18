import Foundation

struct AnthropicResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
    struct Usage: Decodable {
        let input_tokens: Int
        let output_tokens: Int
    }
    let model: String
    let content: [ContentBlock]
    let usage: Usage

    var firstText: String {
        content.first(where: { $0.type == "text" })?.text ?? ""
    }
}

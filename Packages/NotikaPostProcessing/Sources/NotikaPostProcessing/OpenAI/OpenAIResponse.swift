import Foundation

struct OpenAIResponse: Decodable {
    struct OutputItem: Decodable {
        struct ContentPart: Decodable {
            let type: String
            let text: String?
        }
        let type: String
        let role: String?
        let content: [ContentPart]?
    }
    struct Usage: Decodable {
        let input_tokens: Int
        let output_tokens: Int
    }
    let model: String
    let output: [OutputItem]
    let usage: Usage

    var firstText: String {
        for item in output {
            if let parts = item.content {
                for part in parts where part.type == "output_text" {
                    if let text = part.text { return text }
                }
            }
        }
        return ""
    }
}

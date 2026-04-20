import Foundation

struct OpenAIRequest: Encodable {
    let model: String
    let instructions: String
    let input: String
    let temperature: Double
    let max_output_tokens: Int
}

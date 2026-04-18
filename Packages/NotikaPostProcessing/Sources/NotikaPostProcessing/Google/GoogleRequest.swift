import Foundation

struct GoogleRequest: Encodable {
    struct Part: Encodable { let text: String }
    struct Content: Encodable { let parts: [Part]; let role: String? }
    struct SystemInstruction: Encodable { let parts: [Part] }
    struct GenerationConfig: Encodable {
        let temperature: Double
        let maxOutputTokens: Int
    }

    let contents: [Content]
    let systemInstruction: SystemInstruction
    let generationConfig: GenerationConfig

    enum CodingKeys: String, CodingKey {
        case contents
        case systemInstruction = "system_instruction"
        case generationConfig
    }
}

import Foundation

public struct ProcessedText: Sendable, Equatable {
    public let text: String
    public let costUSD: Double?
    public let tokensIn: Int?
    public let tokensOut: Int?
    public let provider: PostProcessingEngineID
    public let model: String?

    public init(
        text: String,
        costUSD: Double? = nil,
        tokensIn: Int? = nil,
        tokensOut: Int? = nil,
        provider: PostProcessingEngineID,
        model: String? = nil
    ) {
        self.text = text
        self.costUSD = costUSD
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.provider = provider
        self.model = model
    }
}

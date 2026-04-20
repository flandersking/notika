import Foundation

public struct CostSnapshot: Codable, Sendable, Equatable {
    public let totalUSD: Double
    public let callCount: Int
    public let lastReset: Date

    public init(totalUSD: Double = 0, callCount: Int = 0, lastReset: Date = Date()) {
        self.totalUSD = totalUSD
        self.callCount = callCount
        self.lastReset = lastReset
    }
}

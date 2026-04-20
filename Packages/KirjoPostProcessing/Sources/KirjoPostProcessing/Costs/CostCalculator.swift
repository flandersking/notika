import Foundation
import KirjoCore

public enum CostCalculator {
    /// Berechnet die USD-Kosten für einen Call. `nil` wenn Modell nicht in Tabelle (z.B. Ollama-Modell).
    public static func cost(modelID: String, tokensIn: Int, tokensOut: Int) -> Double? {
        guard let entry = PricingTable.entry(for: modelID) else { return nil }
        let inCost  = Double(tokensIn)  / 1_000_000.0 * entry.inputUSDPerMillion
        let outCost = Double(tokensOut) / 1_000_000.0 * entry.outputUSDPerMillion
        return inCost + outCost
    }
}

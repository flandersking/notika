import Foundation
import SwiftData

@Model
public final class DictationHistoryEntry {
    public var timestamp: Date
    public var text: String
    public var modeRawValue: String        // wir speichern raw, weil DictationMode-Enum ggf. wandert
    public var providerRawValue: String    // siehe oben
    public var modelID: String?            // bei .none/.apple: nil
    public var costUSD: Double?            // nil bei lokal/keine Daten

    public init(
        timestamp: Date,
        text: String,
        mode: DictationMode,
        provider: PostProcessingEngineID,
        modelID: String?,
        costUSD: Double?
    ) {
        self.timestamp = timestamp
        self.text = text
        self.modeRawValue = mode.rawValue
        self.providerRawValue = provider.rawValue
        self.modelID = modelID
        self.costUSD = costUSD
    }

    public var mode: DictationMode? {
        DictationMode(rawValue: modeRawValue)
    }

    public var provider: PostProcessingEngineID? {
        PostProcessingEngineID(rawValue: providerRawValue)
    }

    public var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 { return trimmed }
        return String(trimmed.prefix(80)) + "…"
    }
}

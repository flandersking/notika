import Foundation
import KirjoCore
import Observation

/// State-Model, das die Pill rendert. Audio-Level und DictationState
/// werden live vom Coordinator (bzw. aktuell vom AppDelegate-Smoketest)
/// in dieses Model gefüttert.
@MainActor
@Observable
public final class PillModel {
    public var state: DictationState = .idle
    public var audioLevel: Float = 0

    /// Historie der letzten N Level-Werte — wird von der Waveform als
    /// Shift-Register verwendet.
    public var levelHistory: [Float]

    public let historySize: Int

    public init(historySize: Int = 16) {
        self.historySize = historySize
        self.levelHistory = Array(repeating: 0, count: historySize)
    }

    public func pushLevel(_ level: Float) {
        audioLevel = level
        levelHistory.removeFirst()
        levelHistory.append(level)
    }

    public func resetHistory() {
        levelHistory = Array(repeating: 0, count: historySize)
        audioLevel = 0
    }

    public var isVisible: Bool {
        if case .idle = state { return false }
        return true
    }

    public var activeMode: DictationMode? {
        switch state {
        case .recording(let mode),
             .initializing(let mode),
             .transcribing(let mode),
             .processing(let mode),
             .inserting(let mode):
            return mode
        case .idle, .error:
            return nil
        }
    }
}

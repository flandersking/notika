import Foundation
import Observation
import KirjoCore

@MainActor
@Observable
public final class WhisperModelDownloadProgress {
    public let modelID: WhisperModelID
    public private(set) var state: State = .pending

    public enum State: Sendable, Equatable {
        case pending
        case downloading(bytesDownloaded: Int64, bytesTotal: Int64)
        case completed
        case failed(WhisperError)
        case cancelled
    }

    public init(modelID: WhisperModelID) {
        self.modelID = modelID
    }

    public func update(_ newState: State) {
        state = newState
    }

    public var fractionCompleted: Double {
        if case .downloading(let done, let total) = state, total > 0 {
            return min(1.0, Double(done) / Double(total))
        }
        if case .completed = state { return 1.0 }
        return 0.0
    }
}

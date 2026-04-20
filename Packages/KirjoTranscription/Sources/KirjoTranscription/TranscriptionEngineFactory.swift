import Foundation
import NotikaCore

public enum TranscriptionEngineFactory {
    public static func availableEngines() -> [TranscriptionEngineID] {
        [.appleSpeechAnalyzer]
    }

    public static func makeEngine(_ id: TranscriptionEngineID) -> TranscriptionEngine {
        switch id {
        case .appleSpeechAnalyzer:
            return AppleSpeechAnalyzerEngine()
        case .whisperCpp:
            // Phase 1b — wird durch `NotikaWhisper.WhisperCppEngine` ersetzt.
            return AppleSpeechAnalyzerEngine()
        }
    }
}

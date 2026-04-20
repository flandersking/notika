import Foundation
import KirjoCore

public enum TranscriptionEngineFactory {
    public static func availableEngines() -> [TranscriptionEngineID] {
        [.appleSpeechAnalyzer]
    }

    public static func makeEngine(_ id: TranscriptionEngineID) -> TranscriptionEngine {
        switch id {
        case .appleSpeechAnalyzer:
            return AppleSpeechAnalyzerEngine()
        case .whisperCpp:
            // Phase 1b — wird durch `KirjoWhisper.WhisperCppEngine` ersetzt.
            return AppleSpeechAnalyzerEngine()
        }
    }
}

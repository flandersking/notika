import Foundation

public struct Transcript: Sendable {
    public let text: String
    public let segments: [Segment]
    public let detectedLanguage: Language?

    public init(text: String, segments: [Segment] = [], detectedLanguage: Language? = nil) {
        self.text = text
        self.segments = segments
        self.detectedLanguage = detectedLanguage
    }

    public struct Segment: Sendable {
        public let text: String
        public let start: TimeInterval
        public let end: TimeInterval

        public init(text: String, start: TimeInterval, end: TimeInterval) {
            self.text = text
            self.start = start
            self.end = end
        }
    }
}

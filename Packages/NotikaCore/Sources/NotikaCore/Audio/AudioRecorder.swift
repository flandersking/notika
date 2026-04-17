import AVFoundation
import Foundation
import os

public enum AudioRecorderError: Error, Sendable {
    case engineFailedToStart
    case fileWriterFailed
    case permissionDenied
}

/// Nimmt Mikrofon-Audio auf, schreibt es als 16 kHz Mono-WAV und emittiert
/// live RMS-Pegel über einen `AsyncStream<Float>`.
///
/// Die Klasse ist **nicht** an `@MainActor` gebunden, weil `AVAudioEngine`
/// seinen Tap-Callback auf einem Realtime-Audio-Thread aufruft. Alle
/// Mutationen sind durch `stateLock` abgesichert.
public final class AudioRecorder: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.notika.mac", category: "AudioRecorder")
    private let engine = AVAudioEngine()
    private let stateLock = NSLock()

    // Diese Properties werden nur unter `stateLock` verändert.
    private var writer: AVAudioFile?
    private var currentURL: URL?
    private var isRunning = false
    private var levelsContinuation: AsyncStream<Float>.Continuation?
    private var currentLevels: AsyncStream<Float>?

    public init() {}

    public var isRecording: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return isRunning
    }

    /// Gibt den aktuell aktiven Level-Stream zurück — oder einen leeren,
    /// wenn gerade nicht aufgenommen wird.
    public func levelStream() -> AsyncStream<Float> {
        stateLock.lock(); defer { stateLock.unlock() }
        return currentLevels ?? AsyncStream { $0.finish() }
    }

    /// Startet die Aufnahme.
    public func start() throws {
        stateLock.lock()
        guard !isRunning else {
            stateLock.unlock()
            return
        }

        let (stream, cont) = AsyncStream<Float>.makeStream()
        self.currentLevels = stream
        self.levelsContinuation = cont

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        logger.info("Input format: \(inputFormat, privacy: .public)")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notika-\(UUID().uuidString).caf")

        // Wir schreiben im nativen Eingabe-Format des Mikrofons (meistens
        // 48 kHz, 32-Bit Float, 1 Kanal). Das vermeidet fehlerhafte Konvertie-
        // rungen. SpeechAnalyzer akzeptiert alle Standard-PCM-Formate.
        do {
            writer = try AVAudioFile(
                forWriting: url,
                settings: inputFormat.settings,
                commonFormat: inputFormat.commonFormat,
                interleaved: inputFormat.isInterleaved
            )
        } catch {
            stateLock.unlock()
            logger.error("Writer init failed: \(error.localizedDescription, privacy: .public)")
            throw AudioRecorderError.fileWriterFailed
        }

        currentURL = url

        // Box, damit wir die nicht-Sendable-Referenz in den Tap-Block übergeben
        // können, ohne den Swift-6-Concurrency-Checker mit @Sendable-Fehlern zu
        // triggern. Die Real-Time-Thread-Sicherheit übernimmt `stateLock`.
        let writerBox = WriterBox(writer: writer)
        let levelsCont = levelsContinuation

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: inputFormat
        ) { buffer, _ in
            let level = AudioRecorder.rmsLevel(from: buffer)
            levelsCont?.yield(level)
            writerBox.write(buffer: buffer)
        }

        do {
            try engine.start()
            isRunning = true
            stateLock.unlock()
            logger.info("Recording gestartet → \(url.path, privacy: .public)")
        } catch {
            inputNode.removeTap(onBus: 0)
            writer = nil
            currentURL = nil
            stateLock.unlock()
            logger.error("Engine start failed: \(error.localizedDescription, privacy: .public)")
            throw AudioRecorderError.engineFailedToStart
        }
    }

    /// Stoppt die Aufnahme und gibt die URL der geschriebenen Datei zurück.
    @discardableResult
    public func stop() -> URL? {
        stateLock.lock(); defer { stateLock.unlock() }
        guard isRunning else { return nil }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false

        levelsContinuation?.finish()
        levelsContinuation = nil
        currentLevels = nil

        let url = currentURL
        currentURL = nil
        writer = nil
        logger.info("Recording gestoppt")
        return url
    }

    // MARK: - Pegel-Berechnung

    /// RMS (root-mean-square) des ersten Channels als Wert zwischen 0 und 1.
    /// `dB`-Bereich -60..0 wird linear auf 0..1 gemappt.
    private static func rmsLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sumOfSquares: Float = 0
        for i in 0..<frameLength {
            let sample = channel[i]
            sumOfSquares += sample * sample
        }
        let rms = sqrt(sumOfSquares / Float(frameLength))
        let db = 20 * log10(max(rms, 1e-6))
        return max(0, min(1, (db + 60) / 60))
    }
}

/// Simpler Wrapper, damit `AVAudioFile` in einem `@Sendable`-Closure benutzt
/// werden kann. File-I/O auf dem Audio-Thread ist bei kleinen Buffern
/// unproblematisch; bei Bedarf kann das später auf eine dedizierte Queue
/// ausgelagert werden.
private final class WriterBox: @unchecked Sendable {
    private let writer: AVAudioFile?
    private let lock = NSLock()

    init(writer: AVAudioFile?) {
        self.writer = writer
    }

    func write(buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        try? writer?.write(from: buffer)
    }
}

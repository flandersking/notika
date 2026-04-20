import Foundation
import AVFoundation

public enum AudioResampler {

    public static func resampleTo16kMono(_ samples: [Float], inputSampleRate: Double) throws -> [Float] {
        guard !samples.isEmpty else { return [] }

        let inputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                        sampleRate: inputSampleRate,
                                        channels: 1,
                                        interleaved: false)!
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: 16_000,
                                         channels: 1,
                                         interleaved: false)!

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw WhisperError.audioResamplingFailed
        }

        let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat,
                                           frameCapacity: AVAudioFrameCount(samples.count))!
        inputBuffer.frameLength = AVAudioFrameCount(samples.count)
        if let chan = inputBuffer.floatChannelData {
            samples.withUnsafeBufferPointer { src in
                chan[0].update(from: src.baseAddress!, count: samples.count)
            }
        }

        let outFrames = AVAudioFrameCount(Double(samples.count) * 16_000 / inputSampleRate) + 1024
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                            frameCapacity: outFrames)!

        var fed = false
        var convError: NSError?
        let status = converter.convert(to: outputBuffer, error: &convError) { _, outStatus in
            if fed {
                outStatus.pointee = .endOfStream
                return nil
            }
            fed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        guard status != .error, convError == nil else {
            throw WhisperError.audioResamplingFailed
        }

        guard let outChan = outputBuffer.floatChannelData else {
            throw WhisperError.audioResamplingFailed
        }
        let outCount = Int(outputBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: outChan[0], count: outCount))
    }
}

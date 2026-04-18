import XCTest
@testable import NotikaWhisper

final class AudioResamplerTests: XCTestCase {

    func test_resample_48kTo16k_outputCount_isOneThird() throws {
        let sampleCount = 48_000
        let frequency: Float = 440
        let samples = (0..<sampleCount).map { i -> Float in
            sin(2 * .pi * frequency * Float(i) / 48_000.0)
        }
        let resampled = try AudioResampler.resampleTo16kMono(samples, inputSampleRate: 48_000)
        XCTAssertGreaterThan(resampled.count, 15_900)
        XCTAssertLessThan(resampled.count, 16_100)
    }

    func test_resample_16kInput_returnsSimilarCount() throws {
        let samples = Array(repeating: Float(0.5), count: 16_000)
        let resampled = try AudioResampler.resampleTo16kMono(samples, inputSampleRate: 16_000)
        XCTAssertGreaterThan(resampled.count, 15_900)
        XCTAssertLessThan(resampled.count, 16_100)
    }

    func test_resample_preservesEnergyApproximately() throws {
        // Band-limited 440 Hz sine (well below 8 kHz Nyquist of 16 kHz output)
        // → anti-aliasing filter shouldn't remove its energy.
        let sampleCount = 48_000
        let frequency: Float = 440
        let samples = (0..<sampleCount).map { i -> Float in
            0.5 * sin(2 * .pi * frequency * Float(i) / 48_000.0)
        }
        let inputRMS = sqrt(samples.reduce(0) { $0 + $1*$1 } / Float(samples.count))
        let resampled = try AudioResampler.resampleTo16kMono(samples, inputSampleRate: 48_000)
        let outputRMS = sqrt(resampled.reduce(0) { $0 + $1*$1 } / Float(resampled.count))
        XCTAssertLessThan(abs(inputRMS - outputRMS) / inputRMS, 0.3)
    }

    func test_resample_emptyInput_returnsEmpty() throws {
        let resampled = try AudioResampler.resampleTo16kMono([], inputSampleRate: 48_000)
        XCTAssertEqual(resampled.count, 0)
    }
}

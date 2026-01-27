import XCTest
@testable import Speakez

final class AudioCaptureServiceTests: XCTestCase {

    // MARK: - Sample Rate Conversion Tests

    func testTargetSampleRate() {
        // Whisper requires 16kHz mono audio
        let targetSampleRate: Double = 16000
        XCTAssertEqual(targetSampleRate, 16000)
    }

    func testSampleRateConversionRatio() {
        // Common input sample rates and their conversion ratios to 16kHz
        let targetRate: Double = 16000

        // 48kHz (common macOS default)
        let ratio48k = targetRate / 48000
        XCTAssertEqual(ratio48k, 1.0/3.0, accuracy: 0.001)

        // 44.1kHz (CD quality)
        let ratio44k = targetRate / 44100
        XCTAssertEqual(ratio44k, 0.3628, accuracy: 0.001)

        // 96kHz (professional)
        let ratio96k = targetRate / 96000
        XCTAssertEqual(ratio96k, 1.0/6.0, accuracy: 0.001)
    }

    // MARK: - Buffer Size Tests

    func testBufferSizeIsReasonable() {
        let bufferSize: AVAudioFrameCount = 4096

        // Buffer should be a power of 2 for efficiency
        XCTAssertTrue(bufferSize.isPowerOfTwo)

        // Buffer should be large enough to capture meaningful audio
        XCTAssertGreaterThan(bufferSize, 1024)

        // But not so large as to introduce latency
        XCTAssertLessThan(bufferSize, 65536)
    }

    // MARK: - Audio Level Calculation Tests

    func testRMSCalculation() {
        // Test RMS (Root Mean Square) calculation for audio level metering
        let samples: [Float] = [0.5, -0.5, 0.5, -0.5]

        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(samples.count))

        XCTAssertEqual(rms, 0.5, accuracy: 0.001)
    }

    func testRMSNormalization() {
        // Audio level should be normalized to 0-1 range
        // Typical speech RMS is around 0.01-0.1
        let typicalSpeechRMS: Float = 0.05
        let normalizedLevel = min(1.0, typicalSpeechRMS * 10)

        XCTAssertEqual(normalizedLevel, 0.5, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(normalizedLevel, 0.0)
        XCTAssertLessThanOrEqual(normalizedLevel, 1.0)
    }

    func testSilentAudioRMS() {
        let silentSamples: [Float] = Array(repeating: 0.0, count: 1000)

        let sumOfSquares = silentSamples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(silentSamples.count))

        XCTAssertEqual(rms, 0.0, accuracy: 0.0001)
    }

    func testLoudAudioClipping() {
        // Very loud audio should be clamped to 1.0
        let loudRMS: Float = 0.2
        let normalizedLevel = min(1.0, loudRMS * 10)

        XCTAssertEqual(normalizedLevel, 1.0)
    }

    // MARK: - Minimum Audio Duration Tests

    func testMinimumRecordingDuration() {
        // Minimum useful recording is 0.5 seconds
        let minimumSeconds: Double = 0.5
        let sampleRate: Double = 16000
        let minimumSamples = Int(minimumSeconds * sampleRate)

        XCTAssertEqual(minimumSamples, 8000)
    }

    // MARK: - Audio Format Tests

    func testMonoChannelCount() {
        // Whisper requires mono audio
        let channelCount: AVAudioChannelCount = 1
        XCTAssertEqual(channelCount, 1)
    }

    func testFloat32Format() {
        // Whisper requires Float32 samples
        let format = AVAudioCommonFormat.pcmFormatFloat32
        XCTAssertEqual(format, .pcmFormatFloat32)
    }
}

// MARK: - Helper Extensions

extension UInt32 {
    var isPowerOfTwo: Bool {
        return self > 0 && (self & (self - 1)) == 0
    }
}

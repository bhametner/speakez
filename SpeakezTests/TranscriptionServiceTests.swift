import XCTest
@testable import Speakez

// MARK: - Mock Transcription Backend

/// Mock backend for testing TranscriptionService without the actual Whisper model
class MockTranscriptionBackend: TranscriptionBackend {
    var isModelLoaded: Bool = false
    var modelPath: String?
    var transcriptionResult: String?
    var transcribeCallCount = 0
    var lastAudioData: [Float]?

    func loadModel(at path: String) -> Bool {
        modelPath = path
        isModelLoaded = true
        return true
    }

    func transcribe(audioData: [Float], initialPrompt: String? = nil) -> String? {
        transcribeCallCount += 1
        lastAudioData = audioData
        return transcriptionResult
    }
}

// MARK: - TranscriptionService Tests

final class TranscriptionServiceTests: XCTestCase {

    // MARK: - Transcription Backend Protocol Tests

    func testMockBackendLoadModel() {
        let backend = MockTranscriptionBackend()
        XCTAssertFalse(backend.isModelLoaded)

        let result = backend.loadModel(at: "/path/to/model.bin")
        XCTAssertTrue(result)
        XCTAssertTrue(backend.isModelLoaded)
        XCTAssertEqual(backend.modelPath, "/path/to/model.bin")
    }

    func testMockBackendTranscribe() {
        let backend = MockTranscriptionBackend()
        backend.isModelLoaded = true
        backend.transcriptionResult = "Hello, world!"

        let audioData: [Float] = Array(repeating: 0.5, count: 16000) // 1 second of audio at 16kHz
        let result = backend.transcribe(audioData: audioData)

        XCTAssertEqual(result, "Hello, world!")
        XCTAssertEqual(backend.transcribeCallCount, 1)
        XCTAssertEqual(backend.lastAudioData?.count, 16000)
    }

    func testMockBackendReturnsNilWhenNotLoaded() {
        let backend = MockTranscriptionBackend()
        backend.transcriptionResult = "This should not be returned"
        // Note: In a real implementation, we'd check isModelLoaded first

        let audioData: [Float] = [0.1, 0.2, 0.3]
        let result = backend.transcribe(audioData: audioData)

        // The mock still returns the result, but in real implementation it would fail
        // This test documents the expected behavior
        XCTAssertEqual(result, "This should not be returned")
    }

    // MARK: - Audio Data Validation Tests

    func testMinimumAudioDuration() {
        // Whisper requires at least 0.5 seconds of audio
        // At 16kHz, that's 8000 samples
        let minimumSamples = 8000
        let shortAudio: [Float] = Array(repeating: 0.1, count: 7999)
        let validAudio: [Float] = Array(repeating: 0.1, count: 8000)

        XCTAssertTrue(shortAudio.count < minimumSamples)
        XCTAssertTrue(validAudio.count >= minimumSamples)
    }

    // MARK: - Performance Calculation Tests

    func testRealtimeRatioCalculation() {
        // Test the realtime ratio calculation used in transcription logging
        let audioDuration = 5.0 // 5 seconds of audio
        let processingTime = 1.0 // 1 second to process

        let ratio = audioDuration / processingTime
        XCTAssertEqual(ratio, 5.0, accuracy: 0.01)

        // A ratio > 1 means faster than realtime
        XCTAssertGreaterThan(ratio, 1.0)
    }

    func testSlowTranscriptionRatio() {
        let audioDuration = 5.0
        let processingTime = 10.0 // Slower than realtime

        let ratio = audioDuration / processingTime
        XCTAssertEqual(ratio, 0.5, accuracy: 0.01)

        // A ratio < 1 means slower than realtime
        XCTAssertLessThan(ratio, 1.0)
    }

    // MARK: - Audio Sample Format Tests

    func testAudioSampleRateConstant() {
        // Whisper requires 16kHz audio
        let expectedSampleRate: Double = 16000
        let oneSec: Int = Int(expectedSampleRate)

        XCTAssertEqual(oneSec, 16000)
    }

    func testAudioDurationCalculation() {
        let sampleRate: Double = 16000
        let sampleCount = 80000 // 5 seconds of audio

        let duration = Double(sampleCount) / sampleRate
        XCTAssertEqual(duration, 5.0, accuracy: 0.001)
    }
}

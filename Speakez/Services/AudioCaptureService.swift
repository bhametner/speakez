import Foundation
import AVFoundation

/// Errors that can occur during audio capture
enum AudioCaptureError: Error {
    case alreadyCapturing
    case failedToCreateFormat
    case engineStartFailed(Error)
}

/// Service for capturing audio from the microphone
/// Outputs 16kHz mono Float32 audio suitable for Whisper
class AudioCaptureService {
    // MARK: - Properties

    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private let captureLock = NSLock()
    private var isCapturing = false

    // Whisper requires 16kHz sample rate
    private let targetSampleRate: Double = 16000

    // Settings
    private let settings = AppSettings.shared

    // Audio level callback (0.0 to 1.0)
    var onAudioLevel: ((Float) -> Void)?

    // MARK: - Initialization

    init() {
        setupAudioSession()
    }

    // MARK: - Setup

    private func setupAudioSession() {
        // macOS doesn't require explicit audio session configuration like iOS
        // But we can configure the audio engine here if needed
    }

    // MARK: - Public Methods

    /// Start capturing audio from the microphone
    /// - Throws: AudioCaptureError if capture cannot be started
    func startCapture() throws {
        captureLock.lock()
        defer { captureLock.unlock() }

        guard !isCapturing else {
            print("AudioCaptureService: Already capturing, ignoring")
            return
        }

        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Calculate the format for Whisper (16kHz mono Float32)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("AudioCaptureService: Failed to create target format")
            throw AudioCaptureError.failedToCreateFormat
        }

        // Create converter if sample rates differ
        let converter: AVAudioConverter?
        if inputFormat.sampleRate != targetSampleRate || inputFormat.channelCount != 1 {
            converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        } else {
            converter = nil
        }

        // Install tap on input node
        let bufferSize: AVAudioFrameCount = 4096

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        do {
            try audioEngine.start()
            isCapturing = true
            print("AudioCaptureService: Started capturing at \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")
        } catch {
            // Clean up the tap if engine failed to start
            inputNode.removeTap(onBus: 0)
            print("AudioCaptureService: Failed to start - \(error.localizedDescription)")
            throw AudioCaptureError.engineStartFailed(error)
        }
    }

    /// Stop capturing and return the captured audio data
    /// - Returns: Array of Float32 samples at 16kHz mono, or nil if no data
    func stopCapture() -> [Float]? {
        captureLock.lock()
        defer { captureLock.unlock() }

        guard isCapturing else { return nil }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isCapturing = false

        bufferLock.lock()
        let capturedData = audioBuffer
        audioBuffer.removeAll()
        bufferLock.unlock()

        let durationSeconds = Double(capturedData.count) / targetSampleRate
        print("AudioCaptureService: Stopped. Captured \(capturedData.count) samples (\(String(format: "%.2f", durationSeconds))s)")

        return capturedData.isEmpty ? nil : capturedData
    }

    /// Check if currently capturing
    var capturing: Bool {
        return isCapturing
    }

    // MARK: - Private Methods

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter?, targetFormat: AVAudioFormat) {
        var processedBuffer: AVAudioPCMBuffer

        if let converter = converter {
            // Need to convert sample rate and/or channels
            let ratio = targetSampleRate / buffer.format.sampleRate
            let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
                return
            }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

            if let error = error {
                print("AudioCaptureService: Conversion error - \(error.localizedDescription)")
                return
            }

            processedBuffer = convertedBuffer
        } else {
            processedBuffer = buffer
        }

        // Extract Float32 data
        guard let channelData = processedBuffer.floatChannelData else { return }

        let frameLength = Int(processedBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Calculate audio level (RMS)
        if let onAudioLevel = onAudioLevel, !samples.isEmpty {
            let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
            let rms = sqrt(sumOfSquares / Float(samples.count))
            // Normalize to 0-1 range (typical speech is around 0.01-0.1 RMS)
            let normalizedLevel = min(1.0, rms * 10)
            DispatchQueue.main.async {
                onAudioLevel(normalizedLevel)
            }
        }

        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        bufferLock.unlock()
    }
}

// MARK: - Audio Device Enumeration

extension AudioCaptureService {
    /// Get list of available audio input devices
    static func availableInputDevices() -> [(id: String, name: String)] {
        var devices: [(id: String, name: String)] = []

        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return devices }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else { return devices }

        for deviceID in deviceIDs {
            // Check if device has input channels
            var inputPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var inputDataSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &inputPropertyAddress, 0, nil, &inputDataSize)

            guard status == noErr, inputDataSize > 0 else { continue }

            let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(inputDataSize))
            defer { bufferListPointer.deallocate() }

            status = AudioObjectGetPropertyData(deviceID, &inputPropertyAddress, 0, nil, &inputDataSize, bufferListPointer)

            guard status == noErr else { continue }

            let bufferList = bufferListPointer.pointee
            var hasInput = false

            // Check if any buffer has channels
            withUnsafePointer(to: &bufferListPointer.pointee.mBuffers) { buffersPtr in
                for i in 0..<Int(bufferList.mNumberBuffers) {
                    let buffer = buffersPtr.advanced(by: i).pointee
                    if buffer.mNumberChannels > 0 {
                        hasInput = true
                        break
                    }
                }
            }

            guard hasInput else { continue }

            // Get device name
            var namePropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var name: CFString = "" as CFString
            var nameDataSize = UInt32(MemoryLayout<CFString>.size)

            status = AudioObjectGetPropertyData(deviceID, &namePropertyAddress, 0, nil, &nameDataSize, &name)

            if status == noErr {
                devices.append((id: String(deviceID), name: name as String))
            }
        }

        return devices
    }
}

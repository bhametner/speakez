import Foundation
import os.log

/// Protocol for speech transcription backends
protocol TranscriptionBackend {
    func transcribe(audioData: [Float], initialPrompt: String?) -> String?
    var isModelLoaded: Bool { get }
    func loadModel(at path: String) -> Bool
}

/// Service for transcribing audio to text using Whisper
class TranscriptionService {
    // MARK: - Properties

    private var backend: TranscriptionBackend?
    private let settings = AppSettings.shared
    private var isInitialized = false

    // Thread configuration - adaptive based on CPU cores
    // Uses processor count minus 2 (minimum 4) for optimal performance
    private var threadCount: Int32 {
        return Int32(max(4, ProcessInfo.processInfo.processorCount - 2))
    }

    // MARK: - Initialization

    init() {
        initializeBackend()
    }

    // MARK: - Public Methods

    /// Transcribe audio data to text
    /// - Parameters:
    ///   - audioData: Array of Float32 samples at 16kHz mono
    ///   - initialPrompt: Optional vocabulary hint string to bias transcription
    /// - Returns: Transcribed text or nil on failure
    func transcribe(audioData: [Float], initialPrompt: String? = nil) -> String? {
        guard let backend = backend, backend.isModelLoaded else {
            Log.transcription.info(" Model not loaded")
            // Try to load the model if not already loaded
            if !loadModelIfNeeded() {
                return nil
            }
            // After loading, check again
            guard let loadedBackend = self.backend, loadedBackend.isModelLoaded else {
                return nil
            }
            return performTranscription(backend: loadedBackend, audioData: audioData, initialPrompt: initialPrompt)
        }

        return performTranscription(backend: backend, audioData: audioData, initialPrompt: initialPrompt)
    }

    private func performTranscription(backend: TranscriptionBackend, audioData: [Float], initialPrompt: String? = nil) -> String? {
        let startTime = CFAbsoluteTimeGetCurrent()

        let result = backend.transcribe(audioData: audioData, initialPrompt: initialPrompt)

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let audioDuration = Double(audioData.count) / 16000.0
        let ratio = audioDuration / elapsed

        Log.transcription.info(" Transcribed \(String(format: "%.2f", audioDuration))s audio in \(String(format: "%.2f", elapsed))s (\(String(format: "%.1f", ratio))x realtime)")

        // Clean up the result
        return result?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// Check if the model is loaded and ready
    var isReady: Bool {
        return backend?.isModelLoaded ?? false
    }

    /// Reload the model (e.g., after changing model in settings)
    func reloadModel() {
        isInitialized = false
        initializeBackend()
    }

    // MARK: - Private Methods

    private func initializeBackend() {
        guard !isInitialized else { return }

        // Try to use the real Whisper backend
        backend = WhisperBackend(threadCount: threadCount)

        // Load the model
        _ = loadModelIfNeeded()

        isInitialized = true
    }

    private func loadModelIfNeeded() -> Bool {
        guard let backend = backend, !backend.isModelLoaded else {
            return backend?.isModelLoaded ?? false
        }

        // First try the selected model from Application Support directory
        if let modelPath = settings.modelPath?.path, FileManager.default.fileExists(atPath: modelPath) {
            Log.transcription.info(" Loading model at \(modelPath)")
            return backend.loadModel(at: modelPath)
        }

        // Try bundled models (check both English and multilingual tiny models)
        let bundledModels = ["ggml-tiny.en", "ggml-tiny"]
        for modelName in bundledModels {
            if let bundledPath = Bundle.main.path(forResource: modelName, ofType: "bin") {
                Log.transcription.info(" Loading bundled model at \(bundledPath)")
                return backend.loadModel(at: bundledPath)
            }
        }

        Log.transcription.info(" No model found. Please download a model.")
        return false
    }
}

// MARK: - Whisper Backend (whisper.cpp wrapper)

/// Backend implementation using whisper.cpp
class WhisperBackend: TranscriptionBackend {
    private var whisperContext: OpaquePointer?
    private let threadCount: Int32

    init(threadCount: Int32 = 4) {
        self.threadCount = threadCount
    }

    deinit {
        if let context = whisperContext {
            whisper_free(context)
        }
    }

    var isModelLoaded: Bool {
        return whisperContext != nil
    }

    func loadModel(at path: String) -> Bool {
        // Free existing context
        if let context = whisperContext {
            whisper_free(context)
            whisperContext = nil
        }

        // Initialize context parameters
        var params = whisper_context_default_params()
        // Enable Metal GPU acceleration on Apple Silicon for faster inference
        #if arch(arm64)
        params.use_gpu = true
        #else
        params.use_gpu = false
        #endif

        // Load the model
        whisperContext = whisper_init_from_file_with_params(path, params)

        if whisperContext != nil {
            Log.transcription.info("WhisperBackend: Model loaded successfully")
            return true
        } else {
            Log.transcription.info("WhisperBackend: Failed to load model at \(path)")
            return false
        }
    }

    func transcribe(audioData: [Float], initialPrompt: String? = nil) -> String? {
        guard let context = whisperContext else {
            Log.transcription.info("WhisperBackend: No context available")
            return nil
        }

        // Configure transcription parameters
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.n_threads = threadCount
        params.offset_ms = 0
        params.no_context = true
        params.single_segment = false
        params.suppress_blank = true
        params.suppress_nst = true

        // Set language from settings (or auto-detect)
        let settings = AppSettings.shared
        let languageStr = settings.transcriptionLanguage == .auto ? "auto" : settings.transcriptionLanguage.rawValue
        let result = languageStr.withCString { langCStr in
            params.language = langCStr

            // Set initial_prompt to bias transcription toward project vocabulary
            if let prompt = initialPrompt, !prompt.isEmpty {
                Log.transcription.info("WhisperBackend: Using vocabulary prompt (\(prompt.count) chars)")
                return prompt.withCString { promptCStr in
                    params.initial_prompt = promptCStr

                    // Run inference
                    return audioData.withUnsafeBufferPointer { bufferPointer in
                        whisper_full(context, params, bufferPointer.baseAddress, Int32(audioData.count))
                    }
                }
            }

            // Run inference without initial prompt
            return audioData.withUnsafeBufferPointer { bufferPointer in
                whisper_full(context, params, bufferPointer.baseAddress, Int32(audioData.count))
            }
        }

        if result != 0 {
            Log.transcription.info("WhisperBackend: Transcription failed with code \(result)")
            return nil
        }

        // Get the transcription result
        let numSegments = whisper_full_n_segments(context)
        var transcription = ""

        for i in 0..<numSegments {
            if let text = whisper_full_get_segment_text(context, i) {
                transcription += String(cString: text)
            }
        }

        return transcription
    }
}

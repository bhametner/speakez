import Foundation
import Carbon.HIToolbox
import ServiceManagement
import os.log

// MARK: - Hotkey Configuration
struct HotkeyConfig: Codable, Equatable, Hashable {
    var keyCode: UInt16
    var modifierFlags: UInt32
    var displayName: String

    static let defaultOption = HotkeyConfig(
        keyCode: UInt16(kVK_Option),
        modifierFlags: 0,
        displayName: "Option (⌥)"
    )

    static let optionKey = HotkeyConfig(
        keyCode: UInt16(kVK_Option),
        modifierFlags: 0,
        displayName: "Option (⌥)"
    )

    static let rightOption = HotkeyConfig(
        keyCode: UInt16(kVK_RightOption),
        modifierFlags: 0,
        displayName: "Right Option (⌥)"
    )

    static let controlKey = HotkeyConfig(
        keyCode: UInt16(kVK_Control),
        modifierFlags: 0,
        displayName: "Control (⌃)"
    )

    static let presets: [HotkeyConfig] = [
        .optionKey,
        .rightOption,
        .controlKey
    ]
}

// MARK: - Transcription Language
enum TranscriptionLanguage: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case polish = "pl"
    case russian = "ru"
    case japanese = "ja"
    case chinese = "zh"
    case korean = "ko"
    case arabic = "ar"
    case hindi = "hi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .dutch: return "Dutch"
        case .polish: return "Polish"
        case .russian: return "Russian"
        case .japanese: return "Japanese"
        case .chinese: return "Chinese"
        case .korean: return "Korean"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        }
    }

    /// Whether this language requires a multilingual model
    var requiresMultilingualModel: Bool {
        return self != .english
    }
}

// MARK: - Whisper Model
enum WhisperModel: String, Codable, CaseIterable, Identifiable {
    // English-only models (smaller, faster for English)
    case tinyEn = "ggml-tiny.en.bin"
    case baseEn = "ggml-base.en.bin"
    case smallEn = "ggml-small.en.bin"

    // Multilingual models (support all languages)
    case tiny = "ggml-tiny.bin"
    case base = "ggml-base.bin"
    case small = "ggml-small.bin"

    var id: String { rawValue }

    var isMultilingual: Bool {
        switch self {
        case .tiny, .base, .small: return true
        case .tinyEn, .baseEn, .smallEn: return false
        }
    }

    var displayName: String {
        switch self {
        case .tinyEn: return "Tiny English (39MB)"
        case .baseEn: return "Base English (142MB)"
        case .smallEn: return "Small English (466MB)"
        case .tiny: return "Tiny Multilingual (39MB)"
        case .base: return "Base Multilingual (142MB)"
        case .small: return "Small Multilingual (466MB)"
        }
    }

    var sizeDescription: String {
        switch self {
        case .tinyEn, .tiny: return "~39MB"
        case .baseEn, .base: return "~142MB"
        case .smallEn, .small: return "~466MB"
        }
    }

    var downloadURL: URL? {
        let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"
        return URL(string: baseURL + rawValue)
    }

    var speedDescription: String {
        switch self {
        case .tinyEn: return "Fastest — English only"
        case .baseEn: return "Balanced — English only"
        case .smallEn: return "Most accurate — English only"
        case .tiny: return "Fastest — All languages"
        case .base: return "Balanced — All languages"
        case .small: return "Most accurate — All languages"
        }
    }

    /// Models grouped by type for UI display
    static var englishModels: [WhisperModel] {
        [.tinyEn, .baseEn, .smallEn]
    }

    static var multilingualModels: [WhisperModel] {
        [.tiny, .base, .small]
    }
}

// MARK: - App Settings
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // Keys
    private enum Keys {
        static let hasCompletedSetup = "hasCompletedSetup"
        static let hotkeyConfig = "hotkeyConfig"
        static let selectedModel = "selectedModel"
        static let playSounds = "playSounds"
        static let autoStartOnLogin = "autoStartOnLogin"
        static let selectedAudioDevice = "selectedAudioDevice"
        static let transcriptionLanguage = "transcriptionLanguage"
        static let clipboardOnlyMode = "clipboardOnlyMode"
    }

    // MARK: - Setup State

    @Published var hasCompletedSetup: Bool {
        didSet {
            defaults.set(hasCompletedSetup, forKey: Keys.hasCompletedSetup)
        }
    }

    // MARK: - Hotkey

    @Published var hotkeyConfig: HotkeyConfig {
        didSet {
            if let encoded = try? JSONEncoder().encode(hotkeyConfig) {
                defaults.set(encoded, forKey: Keys.hotkeyConfig)
            }
        }
    }

    // MARK: - Model

    @Published var selectedModel: WhisperModel {
        didSet {
            defaults.set(selectedModel.rawValue, forKey: Keys.selectedModel)
        }
    }

    // MARK: - Audio & Feedback

    @Published var playSounds: Bool {
        didSet {
            defaults.set(playSounds, forKey: Keys.playSounds)
        }
    }

    @Published var selectedAudioDevice: String? {
        didSet {
            defaults.set(selectedAudioDevice, forKey: Keys.selectedAudioDevice)
        }
    }

    // MARK: - Behavior
    
    /// When true, copy to clipboard but don't auto-paste
    @Published var clipboardOnlyMode: Bool {
        didSet {
            defaults.set(clipboardOnlyMode, forKey: Keys.clipboardOnlyMode)
        }
    }

    // MARK: - General

    @Published var autoStartOnLogin: Bool {
        didSet {
            defaults.set(autoStartOnLogin, forKey: Keys.autoStartOnLogin)
            updateLoginItem()
        }
    }

    @Published var transcriptionLanguage: TranscriptionLanguage {
        didSet {
            defaults.set(transcriptionLanguage.rawValue, forKey: Keys.transcriptionLanguage)
        }
    }

    // MARK: - Initialization

    private init() {
        // Load settings from UserDefaults
        self.hasCompletedSetup = defaults.bool(forKey: Keys.hasCompletedSetup)

        // Load hotkey config
        if let data = defaults.data(forKey: Keys.hotkeyConfig),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            self.hotkeyConfig = config
        } else {
            self.hotkeyConfig = .defaultOption
        }

        // Load model selection (with migration from old enum values)
        if let modelRaw = defaults.string(forKey: Keys.selectedModel),
           let model = WhisperModel(rawValue: modelRaw) {
            self.selectedModel = model
        } else if let modelRaw = defaults.string(forKey: Keys.selectedModel) {
            // Migration: old enum used different raw values
            switch modelRaw {
            case "ggml-tiny.en.bin": self.selectedModel = .tinyEn
            case "ggml-base.en.bin": self.selectedModel = .baseEn
            case "ggml-small.en.bin": self.selectedModel = .smallEn
            default: self.selectedModel = .tinyEn
            }
        } else {
            self.selectedModel = .tinyEn // Default to tiny English for best performance
        }

        self.playSounds = defaults.object(forKey: Keys.playSounds) as? Bool ?? true
        self.autoStartOnLogin = defaults.bool(forKey: Keys.autoStartOnLogin)
        self.selectedAudioDevice = defaults.string(forKey: Keys.selectedAudioDevice)
        if let langRaw = defaults.string(forKey: Keys.transcriptionLanguage),
           let lang = TranscriptionLanguage(rawValue: langRaw) {
            self.transcriptionLanguage = lang
        } else {
            self.transcriptionLanguage = .english
        }
        self.clipboardOnlyMode = defaults.bool(forKey: Keys.clipboardOnlyMode)
    }

    // MARK: - Model Management

    var modelPath: URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport?.appendingPathComponent("Speakez/Models/\(selectedModel.rawValue)")
    }

    var isModelDownloaded: Bool {
        guard let path = modelPath else { return false }
        return FileManager.default.fileExists(atPath: path.path)
    }

    func ensureModelDirectoryExists() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let modelsDir = appSupport?.appendingPathComponent("Speakez/Models")
        if let dir = modelsDir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Login Item

    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if autoStartOnLogin {
                    if service.status != .enabled {
                        try service.register()
                        Log.settings.info(" Registered as login item")
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                        Log.settings.info(" Unregistered from login items")
                    }
                }
            } catch {
                Log.settings.info(" Failed to update login item: \(error.localizedDescription)")
            }
        } else {
            Log.settings.info(" Login items require macOS 13+")
        }
    }

    /// Check current login item status and sync with settings
    func syncLoginItemStatus() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            let isEnabled = service.status == .enabled
            if isEnabled != autoStartOnLogin {
                defaults.set(isEnabled, forKey: Keys.autoStartOnLogin)
                DispatchQueue.main.async {
                    self.autoStartOnLogin = isEnabled
                }
            }
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        hasCompletedSetup = false
        hotkeyConfig = .defaultOption
        selectedModel = .tinyEn
        playSounds = true
        autoStartOnLogin = false
        selectedAudioDevice = nil
        transcriptionLanguage = .english
        clipboardOnlyMode = false
    }
}

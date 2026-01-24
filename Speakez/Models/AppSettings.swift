import Foundation
import Carbon.HIToolbox
import ServiceManagement

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

// MARK: - Whisper Model
enum WhisperModel: String, Codable, CaseIterable {
    case tiny = "ggml-tiny.en.bin"
    case base = "ggml-base.en.bin"
    case small = "ggml-small.en.bin"

    var displayName: String {
        switch self {
        case .tiny: return "Tiny (39MB) — Fastest"
        case .base: return "Base (142MB) — Better accuracy"
        case .small: return "Small (466MB) — Best accuracy"
        }
    }

    var sizeDescription: String {
        switch self {
        case .tiny: return "~39MB"
        case .base: return "~142MB"
        case .small: return "~466MB"
        }
    }

    var downloadURL: URL? {
        let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"
        return URL(string: baseURL + rawValue)
    }

    var speedDescription: String {
        switch self {
        case .tiny: return "~2-3x realtime on Intel"
        case .base: return "~1-1.5x realtime on Intel"
        case .small: return "~0.5x realtime on Intel (slow)"
        }
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

    @Published var transcriptionLanguage: String {
        didSet {
            defaults.set(transcriptionLanguage, forKey: Keys.transcriptionLanguage)
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

        // Load model selection
        if let modelRaw = defaults.string(forKey: Keys.selectedModel),
           let model = WhisperModel(rawValue: modelRaw) {
            self.selectedModel = model
        } else {
            self.selectedModel = .tiny // Default to tiny for Intel performance
        }

        self.playSounds = defaults.object(forKey: Keys.playSounds) as? Bool ?? true
        self.autoStartOnLogin = defaults.bool(forKey: Keys.autoStartOnLogin)
        self.selectedAudioDevice = defaults.string(forKey: Keys.selectedAudioDevice)
        self.transcriptionLanguage = defaults.string(forKey: Keys.transcriptionLanguage) ?? "en"
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
                        print("AppSettings: Registered as login item")
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                        print("AppSettings: Unregistered from login items")
                    }
                }
            } catch {
                print("AppSettings: Failed to update login item: \(error.localizedDescription)")
            }
        } else {
            print("AppSettings: Login items require macOS 13+")
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
        selectedModel = .tiny
        playSounds = true
        autoStartOnLogin = false
        selectedAudioDevice = nil
        transcriptionLanguage = "en"
        clipboardOnlyMode = false
    }
}

import XCTest
@testable import Speakez

final class AppSettingsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear UserDefaults for testing
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "hasCompletedSetup")
        defaults.removeObject(forKey: "hotkeyConfig")
        defaults.removeObject(forKey: "selectedModel")
        defaults.removeObject(forKey: "playSounds")
        defaults.removeObject(forKey: "autoStartOnLogin")
        defaults.removeObject(forKey: "selectedAudioDevice")
        defaults.removeObject(forKey: "transcriptionLanguage")
        defaults.removeObject(forKey: "clipboardOnlyMode")
    }

    // MARK: - Default Values Tests

    func testDefaultTranscriptionLanguageIsEnglish() {
        let settings = AppSettings.shared
        settings.resetToDefaults()
        XCTAssertEqual(settings.transcriptionLanguage, .english)
    }

    func testDefaultModelIsTinyEnglish() {
        let settings = AppSettings.shared
        settings.resetToDefaults()
        XCTAssertEqual(settings.selectedModel, .tinyEn)
    }

    func testDefaultPlaySoundsIsTrue() {
        let settings = AppSettings.shared
        settings.resetToDefaults()
        XCTAssertTrue(settings.playSounds)
    }

    func testDefaultClipboardOnlyModeIsFalse() {
        let settings = AppSettings.shared
        settings.resetToDefaults()
        XCTAssertFalse(settings.clipboardOnlyMode)
    }

    // MARK: - Language Enum Tests

    func testTranscriptionLanguageDisplayNames() {
        XCTAssertEqual(TranscriptionLanguage.english.displayName, "English")
        XCTAssertEqual(TranscriptionLanguage.spanish.displayName, "Spanish")
        XCTAssertEqual(TranscriptionLanguage.auto.displayName, "Auto-detect")
    }

    func testTranscriptionLanguageRequiresMultilingualModel() {
        // English should not require multilingual
        XCTAssertFalse(TranscriptionLanguage.english.requiresMultilingualModel)

        // All other languages should require multilingual
        XCTAssertTrue(TranscriptionLanguage.spanish.requiresMultilingualModel)
        XCTAssertTrue(TranscriptionLanguage.french.requiresMultilingualModel)
        XCTAssertTrue(TranscriptionLanguage.auto.requiresMultilingualModel)
        XCTAssertTrue(TranscriptionLanguage.japanese.requiresMultilingualModel)
    }

    // MARK: - Model Enum Tests

    func testWhisperModelIsMultilingual() {
        // English-only models
        XCTAssertFalse(WhisperModel.tinyEn.isMultilingual)
        XCTAssertFalse(WhisperModel.baseEn.isMultilingual)
        XCTAssertFalse(WhisperModel.smallEn.isMultilingual)

        // Multilingual models
        XCTAssertTrue(WhisperModel.tiny.isMultilingual)
        XCTAssertTrue(WhisperModel.base.isMultilingual)
        XCTAssertTrue(WhisperModel.small.isMultilingual)
    }

    func testWhisperModelDownloadURLs() {
        XCTAssertNotNil(WhisperModel.tinyEn.downloadURL)
        XCTAssertNotNil(WhisperModel.tiny.downloadURL)

        XCTAssertTrue(WhisperModel.tinyEn.downloadURL!.absoluteString.contains("ggml-tiny.en.bin"))
        XCTAssertTrue(WhisperModel.tiny.downloadURL!.absoluteString.contains("ggml-tiny.bin"))
    }

    func testWhisperModelGroups() {
        XCTAssertEqual(WhisperModel.englishModels.count, 3)
        XCTAssertEqual(WhisperModel.multilingualModels.count, 3)

        XCTAssertTrue(WhisperModel.englishModels.allSatisfy { !$0.isMultilingual })
        XCTAssertTrue(WhisperModel.multilingualModels.allSatisfy { $0.isMultilingual })
    }

    // MARK: - Persistence Tests

    func testLanguageSettingPersists() {
        let settings = AppSettings.shared
        settings.transcriptionLanguage = .french

        // The setting should persist in UserDefaults
        let savedValue = UserDefaults.standard.string(forKey: "transcriptionLanguage")
        XCTAssertEqual(savedValue, "fr")
    }

    func testModelSettingPersists() {
        let settings = AppSettings.shared
        settings.selectedModel = .base

        let savedValue = UserDefaults.standard.string(forKey: "selectedModel")
        XCTAssertEqual(savedValue, "ggml-base.bin")
    }

    // MARK: - Model Path Tests

    func testModelPathUsesCorrectFilename() {
        let settings = AppSettings.shared

        settings.selectedModel = .tinyEn
        XCTAssertTrue(settings.modelPath?.lastPathComponent == "ggml-tiny.en.bin")

        settings.selectedModel = .tiny
        XCTAssertTrue(settings.modelPath?.lastPathComponent == "ggml-tiny.bin")
    }

    // MARK: - Reset Tests

    func testResetToDefaults() {
        let settings = AppSettings.shared

        // Change some settings
        settings.transcriptionLanguage = .japanese
        settings.selectedModel = .small
        settings.playSounds = false
        settings.clipboardOnlyMode = true

        // Reset
        settings.resetToDefaults()

        // Verify defaults are restored
        XCTAssertEqual(settings.transcriptionLanguage, .english)
        XCTAssertEqual(settings.selectedModel, .tinyEn)
        XCTAssertTrue(settings.playSounds)
        XCTAssertFalse(settings.clipboardOnlyMode)
    }
}

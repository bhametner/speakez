import SwiftUI
import AVFoundation
import AppKit

@main
struct SpeakezApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Single unified settings window
        Window("Speakez", id: "main") {
            MainSettingsView(appState: appDelegate.appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 750, height: 550)
        .windowResizability(.contentSize)
    }
}

// MARK: - App State
enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case success
    case error(String)
}

class AppState: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var isSetupComplete: Bool = false
    @Published var hasMicrophonePermission: Bool = false
    @Published var hasAccessibilityPermission: Bool = false
    @Published var lastTranscription: String = ""
    @Published var showingPreferences: Bool = false
    @Published var showingSetupWizard: Bool = false
    @Published var showingHistory: Bool = false

    let settings = AppSettings.shared
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var appState = AppState()
    var mainWindow: NSWindow?

    // Recording indicator
    var recordingIndicator: RecordingIndicatorWindow?
    var successIndicator: SuccessIndicatorWindow?

    // Services
    var hotkeyService: HotkeyService?
    var audioCaptureService: AudioCaptureService?
    var transcriptionService: TranscriptionService?
    var textInsertionService: TextInsertionService?
    var soundService: SoundService?
    
    // History
    let historyManager = TranscriptionHistoryManager()

    // Accessibility permission monitoring
    private var accessibilityCheckTimer: Timer?
    
    // Track recording start time for duration
    private var recordingStartTime: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupServices()
        checkPermissions()
        
        // Show main window if first launch or setup incomplete
        if !appState.settings.hasCompletedSetup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showMainWindow()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityCheckTimer?.invalidate()
        accessibilityCheckTimer = nil
        hotkeyService?.stop()
        audioCaptureService?.stopCapture()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateStatusIcon(for: .idle)
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Header
        let headerItem = NSMenuItem(title: "Speakez", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())

        let statusMenuItem = NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Open Speakez...", action: #selector(showMainWindow), keyEquivalent: "o"))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit Speakez", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupServices() {
        // Initialize sound service
        soundService = SoundService()
        
        // Initialize text insertion service
        textInsertionService = TextInsertionService()

        // Initialize transcription service
        transcriptionService = TranscriptionService()

        // Initialize audio capture service
        audioCaptureService = AudioCaptureService()

        // Initialize hotkey service with escape handling
        hotkeyService = HotkeyService(
            onKeyDown: { [weak self] in
                self?.startRecording()
            },
            onKeyUp: { [weak self] in
                self?.stopRecordingAndTranscribe()
            },
            onEscape: { [weak self] in
                self?.cancelRecording()
            }
        )
        hotkeyService?.start()

        // Periodic accessibility permission check
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkAccessibilityPermissionChange()
        }
    }

    private func checkAccessibilityPermissionChange() {
        let trusted = AXIsProcessTrusted()
        let hotkeyActive = hotkeyService?.isActive ?? false
        
        // Trust the hotkey service status over AXIsProcessTrusted
        // because AXIsProcessTrusted can return stale data
        let effectivelyTrusted = trusted || hotkeyActive
        let currentState = appState.hasAccessibilityPermission

        if !effectivelyTrusted && currentState {
            appState.hasAccessibilityPermission = false
            hotkeyService?.stop()
        } else if effectivelyTrusted && !currentState {
            appState.hasAccessibilityPermission = true
            if !hotkeyActive {
                hotkeyService?.start()
            }
        }
    }

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            appState.hasMicrophonePermission = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.appState.hasMicrophonePermission = granted
                }
            }
        default:
            appState.hasMicrophonePermission = false
        }

        // Check accessibility - trust hotkey service status if available
        let axTrusted = AXIsProcessTrusted()
        let hotkeyActive = hotkeyService?.isActive ?? false
        appState.hasAccessibilityPermission = axTrusted || hotkeyActive
    }

    // MARK: - Recording Flow

    private func startRecording() {
        guard case .idle = appState.recordingState else { return }
        guard appState.hasMicrophonePermission else {
            appState.recordingState = .error("Microphone permission required")
            updateStatusIcon(for: appState.recordingState)
            return
        }

        // Play start sound
        if appState.settings.playSounds {
            soundService?.playStartSound()
        }

        // Set up audio level callback
        audioCaptureService?.onAudioLevel = { [weak self] level in
            self?.recordingIndicator?.updateAudioLevel(level)
        }

        do {
            try audioCaptureService?.startCapture()
            recordingStartTime = Date()
        } catch {
            appState.recordingState = .error("Failed to start audio capture")
            updateStatusIcon(for: appState.recordingState)
            return
        }

        DispatchQueue.main.async {
            self.appState.recordingState = .recording
            self.updateStatusIcon(for: .recording)
            self.updateStatusText("Recording...")

            self.recordingIndicator = RecordingIndicatorWindow()
            self.recordingIndicator?.show()
        }
    }
    
    private func cancelRecording() {
        guard case .recording = appState.recordingState else { return }
        
        // Stop capture without transcribing
        _ = audioCaptureService?.stopCapture()
        audioCaptureService?.onAudioLevel = nil
        
        DispatchQueue.main.async {
            self.recordingIndicator?.hide()
            self.recordingIndicator = nil
            
            self.appState.recordingState = .idle
            self.updateStatusIcon(for: .idle)
            self.updateStatusText("Cancelled")
            
            // Play cancel sound
            if self.appState.settings.playSounds {
                self.soundService?.playCancelSound()
            }
            
            // Reset status text after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.updateStatusText("Ready")
            }
        }
    }

    private func stopRecordingAndTranscribe() {
        guard case .recording = appState.recordingState else {
            DispatchQueue.main.async {
                self.recordingIndicator?.hide()
                self.recordingIndicator = nil
            }
            return
        }

        // Calculate duration
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) }
        recordingStartTime = nil

        DispatchQueue.main.async {
            self.recordingIndicator?.hide()
            self.recordingIndicator = nil
        }
        audioCaptureService?.onAudioLevel = nil

        guard let audioData = audioCaptureService?.stopCapture() else {
            DispatchQueue.main.async {
                self.appState.recordingState = .error("No audio captured")
                self.updateStatusIcon(for: self.appState.recordingState)
                self.updateStatusText("Error: No audio")
            }
            return
        }

        // Check minimum audio duration (0.5 seconds at 16kHz = 8000 samples)
        if audioData.count < 8000 {
            DispatchQueue.main.async {
                self.appState.recordingState = .idle
                self.updateStatusIcon(for: .idle)
                self.updateStatusText("Ready (audio too short)")
            }
            return
        }

        DispatchQueue.main.async {
            self.appState.recordingState = .processing
            self.updateStatusIcon(for: .processing)
            self.updateStatusText("Transcribing...")
        }

        // Transcribe in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = self.transcriptionService?.transcribe(audioData: audioData)

            DispatchQueue.main.async {
                if let text = result, !text.isEmpty {
                    self.appState.lastTranscription = text
                    self.appState.recordingState = .success
                    self.updateStatusIcon(for: .success)
                    self.updateStatusText("Success!")
                    
                    // Add to history
                    self.historyManager.add(text: text, duration: duration)

                    // Insert or copy text based on mode
                    if self.appState.settings.clipboardOnlyMode {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } else {
                        self.textInsertionService?.insertText(text)
                    }
                    
                    // Play success sound
                    if self.appState.settings.playSounds {
                        self.soundService?.playSuccessSound()
                    }
                    
                    // Show success indicator
                    self.successIndicator = SuccessIndicatorWindow()
                    self.successIndicator?.show()

                    // Reset to idle after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.appState.recordingState = .idle
                        self.updateStatusIcon(for: .idle)
                        self.updateStatusText("Ready")
                    }
                } else {
                    self.appState.recordingState = .error("Transcription failed")
                    self.updateStatusIcon(for: .error(""))
                    self.updateStatusText("Error: Could not transcribe")
                    
                    // Play error sound
                    if self.appState.settings.playSounds {
                        self.soundService?.playErrorSound()
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.appState.recordingState = .idle
                        self.updateStatusIcon(for: .idle)
                        self.updateStatusText("Ready")
                    }
                }
            }
        }
    }

    // MARK: - UI Updates

    private func updateStatusIcon(for state: RecordingState) {
        guard let button = statusItem?.button else { return }

        let symbolName: String
        let color: NSColor

        switch state {
        case .idle:
            symbolName = "mic"
            color = .secondaryLabelColor
        case .recording:
            symbolName = "mic.fill"
            color = Theme.Colors.NS.recording
        case .processing:
            symbolName = "ellipsis.circle"
            color = NSColor(hex: "3B82F6")
        case .success:
            symbolName = "checkmark.circle.fill"
            color = Theme.Colors.NS.sharpGreen
        case .error:
            symbolName = "exclamationmark.triangle.fill"
            color = NSColor(hex: "F59E0B")
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Speakez") {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let configuredImage = image.withSymbolConfiguration(config)
            button.image = configuredImage
            button.contentTintColor = color
        }
    }

    private func updateStatusText(_ text: String) {
        if let menu = statusItem?.menu,
           let statusItem = menu.item(withTag: 100) {
            statusItem.title = "Status: \(text)"
        }
    }

    // MARK: - Actions

    @objc private func statusItemClicked() {
        statusItem?.button?.performClick(nil)
    }

    @objc func showMainWindow() {
        // Use SwiftUI window management
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Fallback: open via menu
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Sound Service

class SoundService {
    private let startSound: NSSound?
    private let successSound: NSSound?
    private let errorSound: NSSound?
    private let cancelSound: NSSound?
    
    init() {
        // Use system sounds
        startSound = NSSound(named: "Tink")
        successSound = NSSound(named: "Glass")
        errorSound = NSSound(named: "Basso")
        cancelSound = NSSound(named: "Pop")
    }
    
    func playStartSound() {
        startSound?.play()
    }
    
    func playSuccessSound() {
        successSound?.play()
    }
    
    func playErrorSound() {
        errorSound?.play()
    }
    
    func playCancelSound() {
        cancelSound?.play()
    }
}

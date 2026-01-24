import SwiftUI
import AVFoundation

@main
struct SpeakezApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .environmentObject(appDelegate.appState)
        }
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

    let settings = AppSettings.shared
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var appState = AppState()
    var setupWizardWindow: NSWindow?

    // Recording indicator
    var recordingIndicator: RecordingIndicatorWindow?

    // Services
    var hotkeyService: HotkeyService?
    var audioCaptureService: AudioCaptureService?
    var transcriptionService: TranscriptionService?
    var textInsertionService: TextInsertionService?

    // Accessibility permission monitoring
    private var accessibilityCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupServices()
        checkPermissions()

        // Show setup wizard if first launch
        if !appState.settings.hasCompletedSetup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.appState.showingSetupWizard = true
                self.showSetupWizard()
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

        menu.addItem(NSMenuItem(title: "Speakez", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let statusMenuItem = NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Setup Wizard...", action: #selector(showSetupWizard), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupServices() {
        // Initialize text insertion service
        textInsertionService = TextInsertionService()

        // Initialize transcription service
        transcriptionService = TranscriptionService()

        // Initialize audio capture service
        audioCaptureService = AudioCaptureService()

        // Initialize hotkey service
        hotkeyService = HotkeyService(
            onKeyDown: { [weak self] in
                self?.startRecording()
            },
            onKeyUp: { [weak self] in
                self?.stopRecordingAndTranscribe()
            }
        )
        hotkeyService?.start()

        // Fix 5: Set up periodic accessibility permission check
        // Timer fires on main run loop, so we're already on main thread
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkAccessibilityPermissionChange()
        }
    }

    private func checkAccessibilityPermissionChange() {
        let trusted = AXIsProcessTrusted()
        let currentState = appState.hasAccessibilityPermission

        if !trusted && currentState {
            // Permission was revoked
            appState.hasAccessibilityPermission = false
            hotkeyService?.stop()
            NSLog("AppDelegate: Accessibility permission revoked")
        } else if trusted && !currentState {
            // Permission was granted
            appState.hasAccessibilityPermission = true
            hotkeyService?.start()
            NSLog("AppDelegate: Accessibility permission restored")
        }
    }

    private func checkPermissions() {
        // Check microphone permission
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

        // Check accessibility permission
        appState.hasAccessibilityPermission = AXIsProcessTrusted()
    }

    // MARK: - Recording Flow

    private func startRecording() {
        NSLog("AppDelegate: startRecording called")

        // Fix 2: Guard against double-start
        guard case .idle = appState.recordingState else {
            NSLog("AppDelegate: Already recording or processing, ignoring")
            return
        }

        NSLog("AppDelegate: hasMicrophonePermission = %@", appState.hasMicrophonePermission ? "YES" : "NO")

        guard appState.hasMicrophonePermission else {
            NSLog("AppDelegate: No microphone permission!")
            appState.recordingState = .error("Microphone permission required")
            updateStatusIcon(for: appState.recordingState)
            return
        }

        NSLog("AppDelegate: Starting recording...")

        // Set up audio level callback
        audioCaptureService?.onAudioLevel = { [weak self] level in
            self?.recordingIndicator?.updateAudioLevel(level)
        }

        // Fix 3: Start capture first, only update state if successful
        do {
            try audioCaptureService?.startCapture()
        } catch {
            NSLog("AppDelegate: Failed to start audio capture - %@", String(describing: error))
            appState.recordingState = .error("Failed to start audio capture")
            updateStatusIcon(for: appState.recordingState)
            return
        }

        NSLog("AppDelegate: Audio capture started")

        // Only update to recording state after capture successfully started
        DispatchQueue.main.async {
            self.appState.recordingState = .recording
            self.updateStatusIcon(for: .recording)
            self.updateStatusText("Recording...")

            // Show recording indicator
            NSLog("AppDelegate: Showing recording indicator")
            self.recordingIndicator = RecordingIndicatorWindow()
            self.recordingIndicator?.show()
        }
    }

    private func stopRecordingAndTranscribe() {
        NSLog("AppDelegate: stopRecordingAndTranscribe called, state = %@", String(describing: appState.recordingState))
        guard case .recording = appState.recordingState else {
            NSLog("AppDelegate: Not in recording state, skipping")
            // Still try to hide indicator in case it's visible
            DispatchQueue.main.async {
                self.recordingIndicator?.hide()
                self.recordingIndicator = nil
            }
            return
        }

        NSLog("AppDelegate: Hiding recording indicator")
        // Hide recording indicator on main thread
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

                    // Insert text at cursor
                    self.textInsertionService?.insertText(text)

                    // Reset to idle after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.appState.recordingState = .idle
                        self.updateStatusIcon(for: .idle)
                        self.updateStatusText("Ready")
                    }
                } else {
                    self.appState.recordingState = .error("Transcription failed")
                    self.updateStatusIcon(for: .error(""))
                    self.updateStatusText("Error: Could not transcribe")

                    // Reset to idle after delay
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
            color = .systemRed
        case .processing:
            symbolName = "ellipsis.circle"
            color = .systemBlue
        case .success:
            symbolName = "checkmark.circle.fill"
            color = .systemGreen
        case .error:
            symbolName = "exclamationmark.triangle.fill"
            color = .systemYellow
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

    @objc private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showSetupWizard() {
        setupWizardWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        setupWizardWindow?.title = "Speakez Setup"
        setupWizardWindow?.center()
        setupWizardWindow?.contentView = NSHostingView(rootView: SetupWizardView(appState: appState, onComplete: { [weak self] in
            self?.setupWizardWindow?.close()
            self?.setupWizardWindow = nil
        }))
        setupWizardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

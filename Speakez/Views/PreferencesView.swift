import SwiftUI
import AVFoundation

/// Preferences window for configuring app settings
struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var settings = AppSettings.shared

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralPreferencesTab(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            HotkeyPreferencesTab(settings: settings)
                .tabItem {
                    Label("Hotkey", systemImage: "keyboard")
                }
                .tag(1)

            ModelPreferencesTab(settings: settings)
                .tabItem {
                    Label("Model", systemImage: "cpu")
                }
                .tag(2)

            AudioPreferencesTab(settings: settings)
                .tabItem {
                    Label("Audio", systemImage: "mic")
                }
                .tag(3)

            PermissionsPreferencesTab()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
                .tag(4)
        }
        .frame(width: 500, height: 350)
        .padding()
    }
}

// MARK: - General Preferences

struct GeneralPreferencesTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Start at login", isOn: $settings.autoStartOnLogin)
                Toggle("Play sounds", isOn: $settings.playSounds)
            } header: {
                Text("Startup")
            }

            Section {
                Picker("Language", selection: $settings.transcriptionLanguage) {
                    Text("English").tag("en")
                    // More languages can be added here
                }
            } header: {
                Text("Transcription")
            }

            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundColor(.red)
            } header: {
                Text("Reset")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Hotkey Preferences

struct HotkeyPreferencesTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Hotkey", selection: $settings.hotkeyConfig) {
                    ForEach(HotkeyConfig.presets, id: \.keyCode) { config in
                        Text(config.displayName).tag(config)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("Hold the selected key to start recording. Release to transcribe.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Activation Key")
            }

            Section {
                HStack {
                    Text("Current:")
                    Spacer()
                    Text(settings.hotkeyConfig.displayName)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(6)
                }
            } header: {
                Text("Selected Hotkey")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Note: The Fn key cannot be captured on macOS.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Option (⌥) is recommended as it's rarely used alone.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Model Preferences

struct ModelPreferencesTab: View {
    @ObservedObject var settings: AppSettings
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadError: String?

    var body: some View {
        Form {
            Section {
                ForEach(WhisperModel.allCases, id: \.self) { model in
                    ModelRow(
                        model: model,
                        isSelected: settings.selectedModel == model,
                        isDownloaded: isModelDownloaded(model),
                        onSelect: {
                            settings.selectedModel = model
                        },
                        onDownload: {
                            downloadModel(model)
                        }
                    )
                }
            } header: {
                Text("Whisper Model")
            }

            if isDownloading {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Downloading...")
                            .font(.caption)
                        ProgressView(value: downloadProgress)
                    }
                } header: {
                    Text("Download Progress")
                }
            }

            if let error = downloadError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                } header: {
                    Text("Error")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Intel Mac Performance Notes:")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("• tiny.en: Recommended - ~2-3s for 5s audio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• base.en: Slower - may have noticeable delay")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• small.en: Not recommended - too slow for real-time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Performance")
            }
        }
        .formStyle(.grouped)
    }

    private func isModelDownloaded(_ model: WhisperModel) -> Bool {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let modelPath = appSupport?.appendingPathComponent("Speakez/Models/\(model.rawValue)")
        return modelPath != nil && FileManager.default.fileExists(atPath: modelPath!.path)
    }

    private func downloadModel(_ model: WhisperModel) {
        guard let url = model.downloadURL else { return }

        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        settings.ensureModelDirectoryExists()

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let destinationURL = appSupport?.appendingPathComponent("Speakez/Models/\(model.rawValue)") else {
            downloadError = "Could not determine destination path"
            isDownloading = false
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            DispatchQueue.main.async {
                isDownloading = false

                if let error = error {
                    downloadError = error.localizedDescription
                    return
                }

                guard let tempURL = tempURL else {
                    downloadError = "Download failed: no file received"
                    return
                }

                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    print("Model downloaded to \(destinationURL.path)")
                } catch {
                    downloadError = "Failed to save model: \(error.localizedDescription)"
                }
            }
        }

        // Observe download progress
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                downloadProgress = progress.fractionCompleted
            }
        }

        // Store observation to prevent deallocation
        _ = observation

        task.resume()
    }
}

struct ModelRow: View {
    let model: WhisperModel
    let isSelected: Bool
    let isDownloaded: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(model.displayName)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                }
                Text(model.speedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isDownloaded {
                Button("Select") {
                    onSelect()
                }
                .buttonStyle(.bordered)
                .disabled(isSelected)
            } else {
                Button("Download (\(model.sizeDescription))") {
                    onDownload()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Audio Preferences

struct AudioPreferencesTab: View {
    @ObservedObject var settings: AppSettings
    @State private var availableDevices: [(id: String, name: String)] = []

    var body: some View {
        Form {
            Section {
                Picker("Input Device", selection: Binding(
                    get: { settings.selectedAudioDevice ?? "default" },
                    set: { settings.selectedAudioDevice = $0 == "default" ? nil : $0 }
                )) {
                    Text("System Default").tag("default")
                    ForEach(availableDevices, id: \.id) { device in
                        Text(device.name).tag(device.id)
                    }
                }

                Button("Refresh Devices") {
                    refreshDevices()
                }
            } header: {
                Text("Microphone")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio is captured at your device's native sample rate and converted to 16kHz mono for transcription.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Technical Info")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            refreshDevices()
        }
    }

    private func refreshDevices() {
        availableDevices = AudioCaptureService.availableInputDevices()
    }
}

// MARK: - Permissions Preferences

struct PermissionsPreferencesTab: View {
    @State private var hasMicrophonePermission = false
    @State private var hasAccessibilityPermission = false

    var body: some View {
        Form {
            Section {
                PermissionItem(
                    title: "Microphone",
                    description: "Required to capture your voice for transcription",
                    isGranted: hasMicrophonePermission,
                    action: requestMicrophonePermission
                )

                PermissionItem(
                    title: "Accessibility",
                    description: "Required to detect hotkey and insert text in other apps",
                    isGranted: hasAccessibilityPermission,
                    action: openAccessibilitySettings
                )
            } header: {
                Text("Required Permissions")
            }

            Section {
                Text("If permissions are denied, you can grant them in System Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } header: {
                Text("Help")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        // Check microphone
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            hasMicrophonePermission = true
        default:
            hasMicrophonePermission = false
        }

        // Check accessibility
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                hasMicrophonePermission = granted
            }
        }
    }

    private func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        // Also try to open System Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct PermissionItem: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .fontWeight(.medium)
                    Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isGranted ? .green : .red)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isGranted {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
        .environmentObject(AppState())
}

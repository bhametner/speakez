import SwiftUI
import AVFoundation

/// Preferences window for configuring app settings
/// Uses Sharp Geometric design system
struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var settings = AppSettings.shared

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "General", icon: "gearshape", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "Hotkey", icon: "keyboard", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabButton(title: "Model", icon: "cpu", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                TabButton(title: "Audio", icon: "mic", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
                TabButton(title: "Permissions", icon: "lock.shield", isSelected: selectedTab == 4) {
                    selectedTab = 4
                }
            }
            .background(Theme.Colors.secondaryBackground)
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch selectedTab {
                    case 0:
                        GeneralPreferencesTab(settings: settings)
                    case 1:
                        HotkeyPreferencesTab(settings: settings)
                    case 2:
                        ModelPreferencesTab(settings: settings)
                    case 3:
                        AudioPreferencesTab(settings: settings)
                    case 4:
                        PermissionsPreferencesTab()
                    default:
                        EmptyView()
                    }
                }
                .padding(Theme.Spacing.xxl)
            }
            .background(Theme.Colors.background)
        }
        .frame(width: 560, height: 420)
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(isSelected ? Theme.Colors.sharpGreen : Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(isSelected ? Theme.Colors.background : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isSelected ? Theme.Colors.sharpGreen : Color.clear)
                    .frame(height: 2),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Theme.Colors.textSecondary)
            .tracking(1)
            .padding(.bottom, Theme.Spacing.sm)
    }
}

// MARK: - General Preferences

struct GeneralPreferencesTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            // Startup section
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Startup")
                
                SharpToggle(isOn: $settings.autoStartOnLogin, label: "Start at login")
                SharpToggle(isOn: $settings.playSounds, label: "Play sounds")
            }
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            // Behavior section
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Behavior")
                
                SharpToggle(isOn: $settings.clipboardOnlyMode, label: "Clipboard only (don't auto-paste)")
                
                Text("When enabled, transcriptions are copied to clipboard but not automatically pasted.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            // Reset section
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Reset")
                
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .buttonStyle(.sharpDanger)
            }
            
            Spacer()
        }
    }
}

// MARK: - Sharp Toggle

struct SharpToggle: View {
    @Binding var isOn: Bool
    let label: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
            
            Button(action: { isOn.toggle() }) {
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Rectangle()
                        .fill(isOn ? Theme.Colors.sharpGreen : Theme.Colors.border)
                        .frame(width: 44, height: 24)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .padding(2)
                }
            }
            .buttonStyle(.plain)
            .animation(Theme.animation, value: isOn)
        }
    }
}

// MARK: - Hotkey Preferences

struct HotkeyPreferencesTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Activation Key")
                
                VStack(spacing: 0) {
                    ForEach(HotkeyConfig.presets, id: \.keyCode) { config in
                        HotkeyOptionRow(
                            config: config,
                            isSelected: settings.hotkeyConfig == config,
                            onSelect: { settings.hotkeyConfig = config }
                        )
                    }
                }
                .overlay(Rectangle().stroke(Theme.Colors.border, lineWidth: 1))
                
                Text("Hold the selected key to start recording. Release to transcribe.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.top, Theme.Spacing.xs)
            }

            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Current Selection")
                
                HStack {
                    Text(settings.hotkeyConfig.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.Colors.sharpGreen)
                    
                    Spacer()
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.lightGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Note: The Fn key cannot be captured on macOS.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
                Text("Option (⌥) is recommended as it's rarely used alone.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

struct HotkeyOptionRow: View {
    let config: HotkeyConfig
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Rectangle()
                    .fill(isSelected ? Theme.Colors.sharpGreen : Color.clear)
                    .frame(width: 4)
                
                Text(config.displayName)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.leading, Theme.Spacing.md)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.Colors.sharpGreen)
                        .padding(.trailing, Theme.Spacing.md)
                }
            }
            .frame(height: 44)
            .background(isSelected ? Theme.Colors.secondaryBackground : Theme.Colors.background)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model Preferences

struct ModelPreferencesTab: View {
    @ObservedObject var settings: AppSettings
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Whisper Model")
                
                VStack(spacing: 0) {
                    ForEach(WhisperModel.allCases, id: \.self) { model in
                        ModelRow(
                            model: model,
                            isSelected: settings.selectedModel == model,
                            isDownloaded: isModelDownloaded(model),
                            onSelect: { settings.selectedModel = model },
                            onDownload: { downloadModel(model) }
                        )
                        
                        if model != WhisperModel.allCases.last {
                            Rectangle().fill(Theme.Colors.border).frame(height: 1)
                        }
                    }
                }
                .overlay(Rectangle().stroke(Theme.Colors.border, lineWidth: 1))
            }

            if isDownloading {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    SectionHeader(title: "Download Progress")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Theme.Colors.secondaryBackground)
                                Rectangle()
                                    .fill(Theme.Colors.sharpGreen)
                                    .frame(width: geo.size.width * downloadProgress)
                            }
                        }
                        .frame(height: 8)
                        
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Colors.sharpGreen)
                    }
                }
            }

            if let error = downloadError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.error)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader(title: "Performance Notes")
                
                VStack(alignment: .leading, spacing: 6) {
                    PerformanceNote(model: "tiny.en", note: "Recommended — ~2-3s for 5s audio", isRecommended: true)
                    PerformanceNote(model: "base.en", note: "Slower — noticeable delay", isRecommended: false)
                    PerformanceNote(model: "small.en", note: "Not recommended — too slow", isRecommended: false)
                }
            }
            
            Spacer()
        }
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
                } catch {
                    downloadError = "Failed to save model: \(error.localizedDescription)"
                }
            }
        }

        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                downloadProgress = progress.fractionCompleted
            }
        }
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
            Rectangle()
                .fill(isSelected ? Theme.Colors.sharpGreen : Color.clear)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    if isSelected {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.sharpGreen)
                    }
                }
                Text(model.speedDescription)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.leading, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            Spacer()

            if isDownloaded {
                Button("Select") { onSelect() }
                    .buttonStyle(.sharpSecondary)
                    .disabled(isSelected)
                    .opacity(isSelected ? 0.5 : 1)
                    .padding(.trailing, Theme.Spacing.md)
            } else {
                Button("Download") { onDownload() }
                    .buttonStyle(.sharpPrimary)
                    .padding(.trailing, Theme.Spacing.md)
            }
        }
        .frame(minHeight: 56)
        .background(isSelected ? Theme.Colors.secondaryBackground : Theme.Colors.background)
    }
}

struct PerformanceNote: View {
    let model: String
    let note: String
    let isRecommended: Bool
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Rectangle()
                .fill(isRecommended ? Theme.Colors.sharpGreen : Theme.Colors.textSecondary)
                .frame(width: 4, height: 4)
            
            Text(model)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Text("—")
                .foregroundColor(Theme.Colors.textSecondary)
            
            Text(note)
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

// MARK: - Audio Preferences

struct AudioPreferencesTab: View {
    @ObservedObject var settings: AppSettings
    @State private var availableDevices: [(id: String, name: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Microphone")
                
                HStack {
                    Menu {
                        Button("System Default") {
                            settings.selectedAudioDevice = nil
                        }
                        Divider()
                        ForEach(availableDevices, id: \.id) { device in
                            Button(device.name) {
                                settings.selectedAudioDevice = device.id
                            }
                        }
                    } label: {
                        HStack {
                            Text(currentDeviceName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.secondaryBackground)
                    }
                    .menuStyle(.borderlessButton)
                    
                    Button(action: refreshDevices) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                    }
                    .buttonStyle(.plain)
                }
            }

            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader(title: "Technical Info")
                
                Text("Audio is captured at your device's native sample rate and converted to 16kHz mono for transcription.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .onAppear {
            refreshDevices()
        }
    }
    
    private var currentDeviceName: String {
        if let deviceId = settings.selectedAudioDevice,
           let device = availableDevices.first(where: { $0.id == deviceId }) {
            return device.name
        }
        return "System Default"
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
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Required Permissions")
                
                VStack(spacing: 0) {
                    PermissionItem(
                        title: "Microphone",
                        description: "Required to capture your voice for transcription",
                        isGranted: hasMicrophonePermission,
                        action: requestMicrophonePermission
                    )
                    
                    Rectangle().fill(Theme.Colors.border).frame(height: 1)
                    
                    PermissionItem(
                        title: "Accessibility",
                        description: "Required to detect hotkey and insert text in other apps",
                        isGranted: hasAccessibilityPermission,
                        action: openAccessibilitySettings
                    )
                }
                .overlay(Rectangle().stroke(Theme.Colors.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Help")
                
                Text("If permissions are denied, you can grant them in System Settings.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)

                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.sharpSecondary)
            }
            
            Spacer()
        }
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            hasMicrophonePermission = true
        default:
            hasMicrophonePermission = false
        }
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
            Rectangle()
                .fill(isGranted ? Theme.Colors.sharpGreen : Theme.Colors.error)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    if isGranted {
                        Text("GRANTED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.sharpGreen)
                    }
                }
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.leading, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            Spacer()

            if !isGranted {
                Button("Grant") { action() }
                    .buttonStyle(.sharpPrimary)
                    .padding(.trailing, Theme.Spacing.md)
            }
        }
        .frame(minHeight: 56)
        .background(isGranted ? Theme.Colors.secondaryBackground : Theme.Colors.background)
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
        .environmentObject(AppState())
}

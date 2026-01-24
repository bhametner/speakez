import SwiftUI
import AVFoundation

/// Unified settings window with sidebar navigation
/// Replaces separate PreferencesView and SetupWizardView
struct MainSettingsView: View {
    @ObservedObject var appState: AppState
    @StateObject private var settings = AppSettings.shared
    
    @State private var selectedSection: SettingsSection = .general
    
    enum SettingsSection: String, CaseIterable {
        case welcome = "Welcome"
        case general = "General"
        case hotkey = "Hotkey"
        case model = "Model"
        case audio = "Audio"
        case permissions = "Permissions"
        case history = "History"
        
        var icon: String {
            switch self {
            case .welcome: return "hand.wave"
            case .general: return "gearshape"
            case .hotkey: return "keyboard"
            case .model: return "cpu"
            case .audio: return "mic"
            case .permissions: return "lock.shield"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            sidebar
        } detail: {
            // Content
            detailContent
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            // Show welcome if first launch
            if !settings.hasCompletedSetup {
                selectedSection = .welcome
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Logo header
            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    Rectangle()
                        .fill(Theme.Colors.sharpGreen)
                        .frame(width: 32, height: 32)
                    
                    Text("S")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.white)
                }
                
                Text("Speakez")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.secondaryBackground)
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            // Navigation items
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(SettingsSection.allCases, id: \.self) { section in
                        // Hide welcome after setup complete
                        if section == .welcome && settings.hasCompletedSetup {
                            EmptyView()
                        } else {
                            SidebarItem(
                                section: section,
                                isSelected: selectedSection == section,
                                needsAttention: needsAttention(section),
                                onSelect: { selectedSection = section }
                            )
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
            
            Spacer()
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            // Status footer
            statusFooter
        }
        .frame(width: 200)
        .background(Theme.Colors.background)
    }
    
    private func needsAttention(_ section: SettingsSection) -> Bool {
        switch section {
        case .welcome:
            return !settings.hasCompletedSetup
        case .permissions:
            return !appState.hasMicrophonePermission || !appState.hasAccessibilityPermission
        case .model:
            return !settings.isModelDownloaded && Bundle.main.path(forResource: "ggml-tiny.en", ofType: "bin") == nil
        default:
            return false
        }
    }
    
    // MARK: - Status Footer
    
    private var statusFooter: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
    }
    
    private var statusColor: Color {
        if !appState.hasMicrophonePermission || !appState.hasAccessibilityPermission {
            return Theme.Colors.warning
        }
        return Theme.Colors.success
    }
    
    private var statusText: String {
        if !appState.hasAccessibilityPermission {
            return "Accessibility required"
        }
        if !appState.hasMicrophonePermission {
            return "Microphone required"
        }
        return "Ready"
    }
    
    // MARK: - Detail Content
    
    @ViewBuilder
    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Section header
                sectionHeader
                
                Rectangle().fill(Theme.Colors.border).frame(height: 1)
                
                // Section content
                Group {
                    switch selectedSection {
                    case .welcome:
                        WelcomeSection(appState: appState, onComplete: {
                            settings.hasCompletedSetup = true
                            selectedSection = .general
                        })
                    case .general:
                        GeneralSection(settings: settings)
                    case .hotkey:
                        HotkeySection(settings: settings)
                    case .model:
                        ModelSection(settings: settings)
                    case .audio:
                        AudioSection(settings: settings)
                    case .permissions:
                        PermissionsSection(appState: appState)
                    case .history:
                        HistorySection()
                    }
                }
                .padding(Theme.Spacing.xl)
            }
        }
        .background(Theme.Colors.background)
    }
    
    private var sectionHeader: some View {
        HStack {
            Image(systemName: selectedSection.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.Colors.sharpGreen)
            
            Text(selectedSection.rawValue)
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
        }
        .padding(Theme.Spacing.xl)
        .background(Theme.Colors.secondaryBackground)
    }
}

// MARK: - Sidebar Item

struct SidebarItem: View {
    let section: MainSettingsView.SettingsSection
    let isSelected: Bool
    let needsAttention: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Theme.Spacing.sm) {
                Rectangle()
                    .fill(isSelected ? Theme.Colors.sharpGreen : Color.clear)
                    .frame(width: 3)
                
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? Theme.Colors.sharpGreen : Theme.Colors.textSecondary)
                    .frame(width: 20)
                
                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                
                Spacer()
                
                if needsAttention {
                    Circle()
                        .fill(Theme.Colors.warning)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(height: 36)
            .background(isSelected ? Theme.Colors.secondaryBackground : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Welcome Section

struct WelcomeSection: View {
    @ObservedObject var appState: AppState
    let onComplete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            // Hero
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Welcome to Speakez")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Voice-to-text that runs entirely on your device. Private, fast, and works offline.")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            // How it works
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("HOW IT WORKS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1)
                
                VStack(spacing: 0) {
                    WelcomeStepRow(number: "1", title: "Hold Option (⌥)", description: "Start recording your voice")
                    Rectangle().fill(Theme.Colors.border).frame(height: 1)
                    WelcomeStepRow(number: "2", title: "Speak", description: "Say what you want to type")
                    Rectangle().fill(Theme.Colors.border).frame(height: 1)
                    WelcomeStepRow(number: "3", title: "Release", description: "Text appears at your cursor")
                }
                .overlay(Rectangle().stroke(Theme.Colors.border, lineWidth: 1))
            }
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            // Quick status
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("SETUP STATUS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1)
                
                VStack(spacing: Theme.Spacing.sm) {
                    SetupStatusRow(title: "Microphone", isComplete: appState.hasMicrophonePermission)
                    SetupStatusRow(title: "Accessibility", isComplete: appState.hasAccessibilityPermission)
                    SetupStatusRow(title: "AI Model", isComplete: AppSettings.shared.isModelDownloaded || Bundle.main.path(forResource: "ggml-tiny.en", ofType: "bin") != nil)
                }
            }
            
            Spacer()
            
            // Get started button
            if appState.hasMicrophonePermission && appState.hasAccessibilityPermission {
                Button(action: onComplete) {
                    HStack {
                        Text("Get Started")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.sharpPrimary)
            } else {
                Text("Complete the Permissions setup to continue")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }
}

struct WelcomeStepRow: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Rectangle()
                    .fill(Theme.Colors.sharpGreen)
                    .frame(width: 32, height: 32)
                
                Text(number)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(Theme.Spacing.md)
    }
}

struct SetupStatusRow: View {
    let title: String
    let isComplete: Bool
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(isComplete ? Theme.Colors.sharpGreen : Theme.Colors.warning)
                .frame(width: 4, height: 20)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
            
            Text(isComplete ? "Ready" : "Required")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isComplete ? Theme.Colors.sharpGreen : Theme.Colors.warning)
        }
    }
}

// MARK: - General Section

struct GeneralSection: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            // Startup
            SettingsGroup(title: "STARTUP") {
                SharpToggle(isOn: $settings.autoStartOnLogin, label: "Launch at login")
                SharpToggle(isOn: $settings.playSounds, label: "Play feedback sounds")
            }
            
            // Behavior
            SettingsGroup(title: "BEHAVIOR") {
                SharpToggle(isOn: $settings.clipboardOnlyMode, label: "Clipboard only (don't auto-paste)")
                
                Text("When enabled, transcriptions are copied to clipboard but not automatically pasted.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.leading, Theme.Spacing.md)
            }
            
            // Danger zone
            SettingsGroup(title: "RESET") {
                Button("Reset All Settings") {
                    settings.resetToDefaults()
                }
                .buttonStyle(.sharpDanger)
            }
            
            Spacer()
        }
    }
}

// MARK: - Hotkey Section

struct HotkeySection: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            SettingsGroup(title: "ACTIVATION KEY") {
                VStack(spacing: 0) {
                    ForEach(HotkeyConfig.presets, id: \.keyCode) { config in
                        HotkeyOptionRow(
                            config: config,
                            isSelected: settings.hotkeyConfig == config,
                            onSelect: { settings.hotkeyConfig = config }
                        )
                        
                        if config.keyCode != HotkeyConfig.presets.last?.keyCode {
                            Rectangle().fill(Theme.Colors.border).frame(height: 1)
                        }
                    }
                }
                .overlay(Rectangle().stroke(Theme.Colors.border, lineWidth: 1))
                
                Text("Hold the selected key to record. Release to transcribe.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            SettingsGroup(title: "TIPS") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Option (⌥) is recommended — rarely conflicts with shortcuts")
                    Text("• Press Escape to cancel while recording")
                    Text("• The Fn key cannot be used on macOS")
                }
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Model Section

struct ModelSection: View {
    @ObservedObject var settings: AppSettings
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            SettingsGroup(title: "WHISPER MODEL") {
                VStack(spacing: 0) {
                    ForEach(WhisperModel.allCases, id: \.self) { model in
                        ModelOptionRow(
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
                SettingsGroup(title: "DOWNLOADING") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Theme.Colors.secondaryBackground)
                                Rectangle().fill(Theme.Colors.sharpGreen)
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
            
            SettingsGroup(title: "PERFORMANCE") {
                VStack(alignment: .leading, spacing: 6) {
                    PerformanceNote(model: "tiny.en", note: "Recommended — fast and accurate", isRecommended: true)
                    PerformanceNote(model: "base.en", note: "Slower — better for complex audio", isRecommended: false)
                    PerformanceNote(model: "small.en", note: "Slowest — best accuracy", isRecommended: false)
                }
            }
            
            Spacer()
        }
    }
    
    private func isModelDownloaded(_ model: WhisperModel) -> Bool {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let modelPath = appSupport?.appendingPathComponent("Speakez/Models/\(model.rawValue)")
        if let path = modelPath, FileManager.default.fileExists(atPath: path.path) {
            return true
        }
        // Also check bundle
        return Bundle.main.path(forResource: model.rawValue.replacingOccurrences(of: ".bin", with: ""), ofType: "bin") != nil
    }
    
    private func downloadModel(_ model: WhisperModel) {
        guard let url = model.downloadURL else { return }
        
        isDownloading = true
        downloadProgress = 0
        downloadError = nil
        
        settings.ensureModelDirectoryExists()
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let destinationURL = appSupport?.appendingPathComponent("Speakez/Models/\(model.rawValue)") else {
            downloadError = "Could not determine destination"
            isDownloading = false
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            DispatchQueue.main.async {
                isDownloading = false
                
                if let error = error {
                    downloadError = error.localizedDescription
                    return
                }
                
                guard let tempURL = tempURL else {
                    downloadError = "Download failed"
                    return
                }
                
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                } catch {
                    downloadError = error.localizedDescription
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

struct ModelOptionRow: View {
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
                if !isSelected {
                    Button("Select") { onSelect() }
                        .buttonStyle(.sharpSecondary)
                        .padding(.trailing, Theme.Spacing.md)
                }
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

// MARK: - Audio Section

struct AudioSection: View {
    @ObservedObject var settings: AppSettings
    @State private var availableDevices: [(id: String, name: String)] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            SettingsGroup(title: "INPUT DEVICE") {
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
            
            SettingsGroup(title: "TECHNICAL INFO") {
                Text("Audio is captured at your device's native sample rate and converted to 16kHz mono for transcription.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .onAppear { refreshDevices() }
    }
    
    private var currentDeviceName: String {
        if let id = settings.selectedAudioDevice,
           let device = availableDevices.first(where: { $0.id == id }) {
            return device.name
        }
        return "System Default"
    }
    
    private func refreshDevices() {
        availableDevices = AudioCaptureService.availableInputDevices()
    }
}

// MARK: - Permissions Section

struct PermissionsSection: View {
    @ObservedObject var appState: AppState
    @State private var hasMicrophonePermission = false
    @State private var hasAccessibilityPermission = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            SettingsGroup(title: "REQUIRED PERMISSIONS") {
                VStack(spacing: 0) {
                    SettingsPermissionRow(
                        title: "Microphone",
                        description: "Capture your voice for transcription",
                        isGranted: hasMicrophonePermission,
                        onGrant: requestMicrophone
                    )
                    
                    Rectangle().fill(Theme.Colors.border).frame(height: 1)
                    
                    SettingsPermissionRow(
                        title: "Accessibility",
                        description: "Detect hotkey and insert text",
                        isGranted: hasAccessibilityPermission,
                        onGrant: requestAccessibility
                    )
                }
                .overlay(Rectangle().stroke(Theme.Colors.border, lineWidth: 1))
            }
            
            SettingsGroup(title: "HELP") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("If permissions aren't working, try removing and re-adding Speakez in System Settings.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.sharpSecondary)
                }
            }
            
            Spacer()
        }
        .onAppear { checkPermissions() }
    }
    
    private func checkPermissions() {
        hasMicrophonePermission = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        hasAccessibilityPermission = AXIsProcessTrusted()
        appState.hasMicrophonePermission = hasMicrophonePermission
        appState.hasAccessibilityPermission = hasAccessibilityPermission
    }
    
    private func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                hasMicrophonePermission = granted
                appState.hasMicrophonePermission = granted
            }
        }
    }
    
    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct SettingsPermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let onGrant: () -> Void
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(isGranted ? Theme.Colors.sharpGreen : Theme.Colors.warning)
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
            .padding(.vertical, Theme.Spacing.md)
            
            Spacer()
            
            if !isGranted {
                Button("Grant") { onGrant() }
                    .buttonStyle(.sharpPrimary)
                    .padding(.trailing, Theme.Spacing.md)
            }
        }
        .frame(minHeight: 60)
        .background(isGranted ? Theme.Colors.secondaryBackground : Theme.Colors.background)
    }
}

// MARK: - History Section

struct HistorySection: View {
    @StateObject private var historyManager = TranscriptionHistoryManager()
    @State private var searchText = ""
    
    var filteredItems: [TranscriptionHistoryItem] {
        if searchText.isEmpty {
            return historyManager.items
        }
        return historyManager.items.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Search
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.textSecondary)
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Colors.secondaryBackground)
            
            // Stats
            Text("\(historyManager.items.count) transcriptions")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSecondary)
            
            // List
            if filteredItems.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text(searchText.isEmpty ? "No history yet" : "No results")
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            HistoryRow(item: item, onDelete: {
                                historyManager.remove(item)
                            })
                            Rectangle().fill(Theme.Colors.border).frame(height: 1)
                        }
                    }
                    .overlay(Rectangle().stroke(Theme.Colors.border, lineWidth: 1))
                }
            }
            
            if !historyManager.items.isEmpty {
                Button("Clear All History") {
                    historyManager.clearAll()
                }
                .buttonStyle(.sharpDanger)
            }
        }
    }
}

struct HistoryRow: View {
    let item: TranscriptionHistoryItem
    let onDelete: () -> Void
    @State private var copied = false
    
    var body: some View {
        HStack(alignment: .top) {
            Rectangle()
                .fill(Theme.Colors.sharpGreen)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Text(item.text)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
            }
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.leading, Theme.Spacing.sm)
            
            Spacer()
            
            HStack(spacing: 4) {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.text, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }) {
                    Text(copied ? "Copied!" : "Copy")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(copied ? Theme.Colors.sharpGreen : Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.error)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
        }
    }
}

// MARK: - Settings Group

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1)
            
            content
        }
    }
}

// MARK: - Preview

#Preview {
    MainSettingsView(appState: AppState())
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

// MARK: - Hotkey Option Row

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

// MARK: - Performance Note

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

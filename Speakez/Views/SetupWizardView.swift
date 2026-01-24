import SwiftUI
import AVFoundation

/// First-time setup wizard for permissions and model download
/// Uses Sharp Geometric design system
struct SetupWizardView: View {
    @ObservedObject var appState: AppState
    var onComplete: (() -> Void)?

    @State private var currentStep = 0
    @State private var hasMicrophonePermission = false
    @State private var hasAccessibilityPermission = false
    @State private var isDownloadingModel = false
    @State private var downloadProgress: Double = 0
    @State private var downloadError: String?
    @State private var isModelReady = false

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressHeader
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)

            // Content
            VStack(spacing: Theme.Spacing.lg) {
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    microphoneStep
                case 2:
                    accessibilityStep
                case 3:
                    modelStep
                default:
                    completionStep
                }
            }
            .padding(Theme.Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background)

            Rectangle().fill(Theme.Colors.border).frame(height: 1)

            // Navigation
            navigationFooter
        }
        .frame(width: 520, height: 440)
        .background(Theme.Colors.background)
        .onAppear {
            checkPermissions()
            checkModelStatus()
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalSteps, id: \.self) { step in
                // Step indicator
                ZStack {
                    Rectangle()
                        .fill(step <= currentStep ? Theme.Colors.sharpGreen : Theme.Colors.border)
                        .frame(width: 32, height: 32)
                    
                    if step < currentStep {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(step + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(step == currentStep ? .white : Theme.Colors.textSecondary)
                    }
                }

                if step < totalSteps - 1 {
                    Rectangle()
                        .fill(step < currentStep ? Theme.Colors.sharpGreen : Theme.Colors.border)
                        .frame(height: 2)
                        .frame(maxWidth: 60)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.secondaryBackground)
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Icon
            ZStack {
                Rectangle()
                    .fill(Theme.Colors.sharpGreen)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Welcome to Speakez")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Voice-to-text that runs entirely on your device.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                WizardFeatureRow(number: "1", text: "Hold Option (⌥) to start recording")
                Rectangle().fill(Theme.Colors.border).frame(height: 1)
                WizardFeatureRow(number: "2", text: "Speak your text")
                Rectangle().fill(Theme.Colors.border).frame(height: 1)
                WizardFeatureRow(number: "3", text: "Release to insert at cursor")
            }
            .overlay(Rectangle().stroke(Theme.Colors.border, lineWidth: 1))

            Spacer()
        }
    }

    // MARK: - Microphone Step

    private var microphoneStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Rectangle()
                    .fill(hasMicrophonePermission ? Theme.Colors.sharpGreen : Theme.Colors.warning)
                    .frame(width: 80, height: 80)
                
                Image(systemName: hasMicrophonePermission ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Microphone Access")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Speakez needs to hear your voice to transcribe it.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if hasMicrophonePermission {
                HStack(spacing: Theme.Spacing.sm) {
                    Rectangle()
                        .fill(Theme.Colors.sharpGreen)
                        .frame(width: 8, height: 8)
                    Text("Microphone access granted")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.sharpGreen)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.lightGreen)
            } else {
                Button("Grant Microphone Access") {
                    requestMicrophonePermission()
                }
                .buttonStyle(.sharpPrimary)
            }

            Spacer()

            HStack {
                Rectangle()
                    .fill(Theme.Colors.sharpGreen)
                    .frame(width: 4)
                Text("Your audio is processed locally and never sent to any server.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
        }
    }

    // MARK: - Accessibility Step

    private var accessibilityStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Rectangle()
                    .fill(hasAccessibilityPermission ? Theme.Colors.sharpGreen : Theme.Colors.warning)
                    .frame(width: 80, height: 80)
                
                Image(systemName: hasAccessibilityPermission ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Accessibility Access")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Required to detect hotkey and insert text in other apps.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if hasAccessibilityPermission {
                HStack(spacing: Theme.Spacing.sm) {
                    Rectangle()
                        .fill(Theme.Colors.sharpGreen)
                        .frame(width: 8, height: 8)
                    Text("Accessibility access granted")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.sharpGreen)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.lightGreen)
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Button("Open Accessibility Settings") {
                        openAccessibilitySettings()
                    }
                    .buttonStyle(.sharpPrimary)

                    Text("Add Speakez in System Settings → Privacy & Security → Accessibility")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    Button("Check Again") {
                        checkPermissions()
                    }
                    .buttonStyle(.sharpSecondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Model Step

    private var modelStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Rectangle()
                    .fill(isModelReady ? Theme.Colors.sharpGreen : Theme.Colors.processing)
                    .frame(width: 80, height: 80)
                
                Image(systemName: isModelReady ? "cpu.fill" : "arrow.down")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Download AI Model")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("A local AI model powers the speech recognition.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            if isModelReady {
                HStack(spacing: Theme.Spacing.sm) {
                    Rectangle()
                        .fill(Theme.Colors.sharpGreen)
                        .frame(width: 8, height: 8)
                    Text("Model ready")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.sharpGreen)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.lightGreen)
            } else if isDownloadingModel {
                VStack(spacing: Theme.Spacing.sm) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Theme.Colors.secondaryBackground)
                            Rectangle()
                                .fill(Theme.Colors.sharpGreen)
                                .frame(width: geo.size.width * downloadProgress)
                        }
                    }
                    .frame(width: 240, height: 8)
                    
                    Text("Downloading... \(Int(downloadProgress * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Colors.sharpGreen)
                }
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    if let error = downloadError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.error)
                    }

                    Button("Download tiny.en Model (~39MB)") {
                        downloadModel()
                    }
                    .buttonStyle(.sharpPrimary)

                    Text("Recommended for fast, accurate transcription")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Completion Step

    private var completionStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Rectangle()
                    .fill(Theme.Colors.sharpGreen)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Hold Option and start speaking.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                WizardTipRow(icon: "option", text: "Hold Option (⌥) to record")
                Rectangle().fill(Theme.Colors.border).frame(height: 1)
                WizardTipRow(icon: "escape", text: "Press Escape to cancel")
                Rectangle().fill(Theme.Colors.border).frame(height: 1)
                WizardTipRow(icon: "gearshape", text: "Click menu bar icon for settings")
            }
            .overlay(Rectangle().stroke(Theme.Colors.border, lineWidth: 1))

            Spacer()
        }
    }

    // MARK: - Navigation Footer

    private var navigationFooter: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation(Theme.animation) {
                        currentStep -= 1
                    }
                }
                .buttonStyle(.sharpSecondary)
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                Button(canProceed ? "Next" : "Skip") {
                    withAnimation(Theme.animation) {
                        currentStep += 1
                    }
                }
                .buttonStyle(.sharpPrimary)
            } else {
                Button("Get Started") {
                    completeSetup()
                }
                .buttonStyle(.sharpPrimary)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.secondaryBackground)
    }

    // MARK: - Helpers

    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return hasMicrophonePermission
        case 2:
            return hasAccessibilityPermission
        case 3:
            return isModelReady
        default:
            return true
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

        appState.hasMicrophonePermission = hasMicrophonePermission
        appState.hasAccessibilityPermission = hasAccessibilityPermission
    }

    private func checkModelStatus() {
        let settings = AppSettings.shared
        if let modelPath = settings.modelPath?.path {
            isModelReady = FileManager.default.fileExists(atPath: modelPath)
        }

        if Bundle.main.path(forResource: "ggml-tiny.en", ofType: "bin") != nil {
            isModelReady = true
        }
    }

    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                hasMicrophonePermission = granted
                appState.hasMicrophonePermission = granted
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

    private func downloadModel() {
        let settings = AppSettings.shared
        guard let url = WhisperModel.tiny.downloadURL else { return }

        isDownloadingModel = true
        downloadProgress = 0
        downloadError = nil

        settings.ensureModelDirectoryExists()

        guard let destinationURL = settings.modelPath else {
            downloadError = "Could not determine destination path"
            isDownloadingModel = false
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            DispatchQueue.main.async {
                isDownloadingModel = false

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
                    isModelReady = true
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

    private func completeSetup() {
        appState.settings.hasCompletedSetup = true
        appState.isSetupComplete = true
        onComplete?()
    }
}

// MARK: - Wizard Feature Row

struct WizardFeatureRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Rectangle()
                    .fill(Theme.Colors.sharpGreen)
                    .frame(width: 28, height: 28)
                
                Text(number)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
        }
        .padding(Theme.Spacing.md)
    }
}

// MARK: - Wizard Tip Row

struct WizardTipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Colors.sharpGreen)
                .frame(width: 28)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
        }
        .padding(Theme.Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    SetupWizardView(appState: AppState(), onComplete: nil)
}

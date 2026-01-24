import SwiftUI
import AVFoundation

/// First-time setup wizard for permissions and model download
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

            Divider()

            // Content
            VStack(spacing: 20) {
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
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation
            navigationFooter
        }
        .frame(width: 500, height: 400)
        .onAppear {
            checkPermissions()
            checkModelStatus()
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 10, height: 10)

                if step < totalSteps - 1 {
                    Rectangle()
                        .fill(step < currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                }
            }
        }
        .padding()
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Welcome to Speakez")
                .font(.title)
                .fontWeight(.semibold)

            Text("This app lets you dictate text anywhere on your Mac by holding a hotkey.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "keyboard", text: "Hold Option (⌥) to start recording")
                FeatureRow(icon: "waveform", text: "Speak your text")
                FeatureRow(icon: "text.cursor", text: "Release to insert at cursor")
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)

            Spacer()
        }
    }

    // MARK: - Microphone Step

    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: hasMicrophonePermission ? "mic.circle.fill" : "mic.slash.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(hasMicrophonePermission ? .green : .orange)

            Text("Microphone Access")
                .font(.title)
                .fontWeight(.semibold)

            Text("Speakez needs microphone access to hear your voice and transcribe it to text.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()

            if hasMicrophonePermission {
                Label("Microphone access granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant Microphone Access") {
                    requestMicrophonePermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()

            Text("Your audio is processed locally on your device and never sent to any server.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Accessibility Step

    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: hasAccessibilityPermission ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(hasAccessibilityPermission ? .green : .orange)

            Text("Accessibility Access")
                .font(.title)
                .fontWeight(.semibold)

            Text("Speakez needs accessibility access to detect the hotkey and insert text in other applications.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()

            if hasAccessibilityPermission {
                Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                VStack(spacing: 12) {
                    Button("Open Accessibility Settings") {
                        openAccessibilitySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Add Speakez to the list in System Settings > Privacy & Security > Accessibility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Check Again") {
                        checkPermissions()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
    }

    // MARK: - Model Step

    private var modelStep: some View {
        VStack(spacing: 16) {
            Image(systemName: isModelReady ? "cpu.fill" : "arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(isModelReady ? .green : .accentColor)

            Text("Download Speech Model")
                .font(.title)
                .fontWeight(.semibold)

            Text("Speakez uses a local AI model to transcribe your speech. This model runs entirely on your device.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()

            if isModelReady {
                Label("Model ready", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if isDownloadingModel {
                VStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .frame(width: 200)
                    Text("Downloading... \(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    if let error = downloadError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Button("Download tiny.en Model (~39MB)") {
                        downloadModel()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Recommended for Intel Macs - fast and accurate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Completion Step

    private var completionStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Setup Complete!")
                .font(.title)
                .fontWeight(.semibold)

            Text("You're ready to use Speakez. Hold the Option key and start speaking!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Tips:")
                    .fontWeight(.medium)
                FeatureRow(icon: "option", text: "Hold Option (⌥) to record")
                FeatureRow(icon: "hand.raised", text: "Release to transcribe and insert")
                FeatureRow(icon: "gearshape", text: "Click menu bar icon for settings")
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)

            Spacer()
        }
    }

    // MARK: - Navigation Footer

    private var navigationFooter: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                Button(canProceed ? "Next" : "Skip") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    completeSetup()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
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
        // Check microphone
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            hasMicrophonePermission = true
        default:
            hasMicrophonePermission = false
        }

        // Check accessibility
        hasAccessibilityPermission = AXIsProcessTrusted()

        // Update app state
        appState.hasMicrophonePermission = hasMicrophonePermission
        appState.hasAccessibilityPermission = hasAccessibilityPermission
    }

    private func checkModelStatus() {
        let settings = AppSettings.shared
        if let modelPath = settings.modelPath?.path {
            isModelReady = FileManager.default.fileExists(atPath: modelPath)
        }

        // Also check bundled model
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

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    SetupWizardView(appState: AppState(), onComplete: nil)
}

import SwiftUI

/// Menu bar popover view showing app status and quick controls
struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Speakez")
                    .font(.headline)
                Spacer()
                statusBadge
            }

            Divider()

            // Status
            statusSection

            Divider()

            // Last transcription
            if !appState.lastTranscription.isEmpty {
                lastTranscriptionSection
                Divider()
            }

            // Quick info
            infoSection

            Divider()

            // Actions
            actionsSection
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle:
            return .green
        case .recording:
            return .red
        case .processing:
            return .blue
        case .success:
            return .green
        case .error:
            return .yellow
        }
    }

    private var statusText: String {
        switch appState.recordingState {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .success:
            return "Success"
        case .error(let message):
            return message
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text(statusTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var statusIcon: String {
        switch appState.recordingState {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .processing:
            return "ellipsis.circle"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusTitle: String {
        switch appState.recordingState {
        case .idle:
            return "Ready to Record"
        case .recording:
            return "Recording..."
        case .processing:
            return "Transcribing..."
        case .success:
            return "Transcription Complete"
        case .error:
            return "Error"
        }
    }

    private var statusSubtitle: String {
        let hotkeyName = appState.settings.hotkeyConfig.displayName
        switch appState.recordingState {
        case .idle:
            return "Hold \(hotkeyName) to start"
        case .recording:
            return "Release \(hotkeyName) to transcribe"
        case .processing:
            return "Please wait..."
        case .success:
            return "Text inserted at cursor"
        case .error(let message):
            return message
        }
    }

    // MARK: - Last Transcription Section

    private var lastTranscriptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last Transcription")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(appState.lastTranscription)
                .font(.caption)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            PermissionRow(
                title: "Microphone",
                isGranted: appState.hasMicrophonePermission
            )
            PermissionRow(
                title: "Accessibility",
                isGranted: appState.hasAccessibilityPermission
            )
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 8) {
            Button("Preferences...") {
                appState.showingPreferences = true
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)

            Button("Quit Speakez") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
                .font(.caption)

            Text(title)
                .font(.caption)

            Spacer()

            Text(isGranted ? "Granted" : "Required")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Recording Indicator Overlay

struct RecordingIndicatorOverlay: View {
    @ObservedObject var appState: AppState

    var body: some View {
        if case .recording = appState.recordingState {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    recordingIndicator
                        .padding()
                }
            }
        }
    }

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .scaleEffect(1.5)
                )

            Text("Recording...")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(20)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(appState: {
        let state = AppState()
        state.lastTranscription = "Hello, this is a test transcription."
        return state
    }())
}

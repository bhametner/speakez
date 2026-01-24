import SwiftUI

/// Menu bar popover view showing app status and quick controls
/// Uses Sharp Geometric design system
struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)

            // Status
            statusSection
                .padding(Theme.Spacing.lg)
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)

            // Last transcription
            if !appState.lastTranscription.isEmpty {
                lastTranscriptionSection
                    .padding(Theme.Spacing.lg)
                
                Rectangle().fill(Theme.Colors.border).frame(height: 1)
            }

            // Permissions
            permissionsSection
                .padding(Theme.Spacing.lg)
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)

            // Actions
            actionsSection
                .padding(Theme.Spacing.lg)
        }
        .frame(width: 300)
        .background(Theme.Colors.background)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            // Logo mark
            Text("S")
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Theme.Colors.sharpGreen)
            
            Text("Speakez")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
            
            statusBadge
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.background)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.Colors.secondaryBackground)
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle:
            return Theme.Colors.success
        case .recording:
            return Theme.Colors.recording
        case .processing:
            return Theme.Colors.processing
        case .success:
            return Theme.Colors.success
        case .error:
            return Theme.Colors.warning
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
        case .error:
            return "Error"
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Status icon
            ZStack {
                Rectangle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(statusSubtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
        }
    }

    private var statusIcon: String {
        switch appState.recordingState {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .processing:
            return "ellipsis"
        case .success:
            return "checkmark"
        case .error:
            return "exclamationmark"
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
            return "Release to transcribe • Esc to cancel"
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
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text("LAST TRANSCRIPTION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.lastTranscription, forType: .string)
                }) {
                    Text("COPY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.sharpGreen)
                        .tracking(1)
                }
                .buttonStyle(.plain)
            }

            Text(appState.lastTranscription)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.secondaryBackground)
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("PERMISSIONS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1)
            
            VStack(spacing: 6) {
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
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Button(action: {
                appState.showingPreferences = true
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }) {
                HStack {
                    Image(systemName: "gearshape")
                    Text("Preferences")
                    Spacer()
                    Text("⌘,")
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                appState.showingHistory = true
            }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                    Spacer()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            Rectangle().fill(Theme.Colors.border).frame(height: 1)
                .padding(.vertical, 4)

            Button(action: {
                NSApp.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Speakez")
                    Spacer()
                    Text("⌘Q")
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.error)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack {
            Rectangle()
                .fill(isGranted ? Theme.Colors.success : Theme.Colors.error)
                .frame(width: 6, height: 6)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            Text(isGranted ? "Granted" : "Required")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isGranted ? Theme.Colors.textSecondary : Theme.Colors.error)
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(appState: {
        let state = AppState()
        state.lastTranscription = "Hello, this is a test transcription that might be a bit longer."
        return state
    }())
}

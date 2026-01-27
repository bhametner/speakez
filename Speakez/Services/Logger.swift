import Foundation
import os.log

/// Centralized logging utility using Apple's unified logging system (os_log)
/// Provides structured logging with different categories for each service
enum Log {
    // MARK: - Loggers for each category

    /// Logger for app lifecycle and general events
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Logger for transcription service
    static let transcription = Logger(subsystem: subsystem, category: "transcription")

    /// Logger for audio capture service
    static let audio = Logger(subsystem: subsystem, category: "audio")

    /// Logger for hotkey service
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")

    /// Logger for text insertion service
    static let textInsertion = Logger(subsystem: subsystem, category: "textInsertion")

    /// Logger for settings
    static let settings = Logger(subsystem: subsystem, category: "settings")

    /// Logger for permissions
    static let permissions = Logger(subsystem: subsystem, category: "permissions")

    // MARK: - Private

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.speakez"
}

// MARK: - Convenience Extensions

extension Logger {
    /// Log a debug message (only visible in Console.app with debug level enabled)
    func debug(_ message: String) {
        self.debug("\(message, privacy: .public)")
    }

    /// Log an info message
    func info(_ message: String) {
        self.info("\(message, privacy: .public)")
    }

    /// Log a warning message
    func warning(_ message: String) {
        self.warning("\(message, privacy: .public)")
    }

    /// Log an error message
    func error(_ message: String) {
        self.error("\(message, privacy: .public)")
    }

    /// Log performance metrics
    func performance(_ operation: String, duration: Double, details: String? = nil) {
        if let details = details {
            self.info("[\(operation)] \(String(format: "%.2f", duration * 1000))ms - \(details)")
        } else {
            self.info("[\(operation)] \(String(format: "%.2f", duration * 1000))ms")
        }
    }
}

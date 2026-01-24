import SwiftUI
import AppKit

/// A small floating window that shows recording status and audio level
class RecordingIndicatorWindow {
    private var window: NSWindow?
    private var levelView: NSProgressIndicator?

    func show() {
        // Ensure we're on main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.show()
            }
            return
        }

        guard window == nil else { return }
        createAndShowWindow()
    }

    private func createAndShowWindow() {
        // Create a simple NSWindow (not NSPanel to avoid some issues)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 50),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Round corners
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 10
        window.contentView?.layer?.masksToBounds = true

        // Position at top center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 90
            let y = screenFrame.maxY - 70
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Create content using AppKit (simpler, less crash-prone)
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 50))

        // Recording dot
        let dot = NSView(frame: NSRect(x: 15, y: 19, width: 12, height: 12))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.red.cgColor
        dot.layer?.cornerRadius = 6
        contentView.addSubview(dot)

        // Level indicator
        let level = NSProgressIndicator(frame: NSRect(x: 35, y: 17, width: 60, height: 16))
        level.style = .bar
        level.isIndeterminate = false
        level.minValue = 0
        level.maxValue = 1
        level.doubleValue = 0
        contentView.addSubview(level)
        self.levelView = level

        // Label
        let label = NSTextField(labelWithString: "Recording...")
        label.frame = NSRect(x: 100, y: 15, width: 75, height: 20)
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        contentView.addSubview(label)

        window.contentView = contentView
        self.window = window

        window.orderFront(nil)
    }

    func hide() {
        // Ensure we're on main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.hide()
            }
            return
        }

        NSLog("RecordingIndicatorWindow: Closing window")
        levelView = nil
        if let window = self.window {
            self.window = nil
            window.orderOut(nil)
        }
    }

    func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.levelView?.doubleValue = Double(level)
        }
    }
}

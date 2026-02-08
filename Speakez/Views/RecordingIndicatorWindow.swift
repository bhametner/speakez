import SwiftUI
import AppKit

/// A small floating window that shows recording status and audio level
/// Uses Sharp Geometric design system - no rounded corners
class RecordingIndicatorWindow {
    private var window: NSWindow?
    private var levelView: NSView?
    private var levelWidthConstraint: NSLayoutConstraint?
    private var maxLevelWidth: CGFloat = 80

    func show() {
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
        let windowWidth: CGFloat = 200
        let windowHeight: CGFloat = 48

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Sharp corners - no rounding
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 0

        // Position at top center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.maxY - 70
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Use NSVisualEffectView for automatic vibrancy on light/dark desktops
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 0

        // Left accent bar (Recording Red)
        let accentBar = NSView(frame: NSRect(x: 0, y: 0, width: 4, height: windowHeight))
        accentBar.wantsLayer = true
        accentBar.layer?.backgroundColor = Theme.Colors.NS.recording.cgColor
        visualEffect.addSubview(accentBar)

        // Recording indicator dot (pulsing)
        let dotContainer = NSView(frame: NSRect(x: 16, y: (windowHeight - 12) / 2, width: 12, height: 12))
        dotContainer.wantsLayer = true
        dotContainer.layer?.backgroundColor = Theme.Colors.NS.recording.cgColor
        visualEffect.addSubview(dotContainer)

        // Add pulse animation
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.4
        pulseAnimation.duration = 0.6
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        dotContainer.layer?.add(pulseAnimation, forKey: "pulse")

        // Level meter background
        let levelBg = NSView(frame: NSRect(x: 36, y: (windowHeight - 8) / 2, width: maxLevelWidth, height: 8))
        levelBg.wantsLayer = true
        levelBg.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        visualEffect.addSubview(levelBg)

        // Level meter fill
        let levelFill = NSView(frame: NSRect(x: 36, y: (windowHeight - 8) / 2, width: 0, height: 8))
        levelFill.wantsLayer = true
        levelFill.layer?.backgroundColor = Theme.Colors.NS.sharpGreen.cgColor
        visualEffect.addSubview(levelFill)
        self.levelView = levelFill

        // Label - use vibrant label color for automatic contrast
        let label = NSTextField(labelWithString: "RECORDING")
        label.frame = NSRect(x: 124, y: (windowHeight - 16) / 2, width: 80, height: 16)
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        label.alignment = .left
        visualEffect.addSubview(label)

        // Esc hint
        let escHint = NSTextField(labelWithString: "Esc to cancel")
        escHint.frame = NSRect(x: 36, y: 6, width: 100, height: 12)
        escHint.textColor = Theme.Colors.NS.textSecondary
        escHint.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        visualEffect.addSubview(escHint)

        window.contentView = visualEffect
        self.window = window

        window.orderFront(nil)
    }

    func hide() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.hide()
            }
            return
        }

        levelView = nil
        if let window = self.window {
            self.window = nil
            window.orderOut(nil)
        }
    }

    func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let levelView = self.levelView else { return }
            
            let width = CGFloat(level) * self.maxLevelWidth
            var frame = levelView.frame
            frame.size.width = max(2, width) // minimum 2px
            levelView.frame = frame
        }
    }
}

// MARK: - Success Indicator

/// Brief success flash indicator
class SuccessIndicatorWindow {
    private var window: NSWindow?
    
    func show() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.show()
            }
            return
        }

        let windowWidth: CGFloat = 160
        let windowHeight: CGFloat = 48

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.maxY - 70
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Green background container
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = Theme.Colors.NS.sharpGreen.cgColor

        // Checkmark
        let checkmark = NSTextField(labelWithString: "✓")
        checkmark.frame = NSRect(x: 16, y: (windowHeight - 20) / 2, width: 24, height: 20)
        checkmark.textColor = .white
        checkmark.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        contentView.addSubview(checkmark)

        // Label
        let label = NSTextField(labelWithString: "INSERTED")
        label.frame = NSRect(x: 44, y: (windowHeight - 16) / 2, width: 100, height: 16)
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        contentView.addSubview(label)

        window.contentView = contentView
        self.window = window
        window.orderFront(nil)

        // Auto-hide after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.hide()
        }
    }
    
    func hide() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.hide()
            }
            return
        }
        
        if let window = self.window {
            self.window = nil
            window.orderOut(nil)
        }
    }
}

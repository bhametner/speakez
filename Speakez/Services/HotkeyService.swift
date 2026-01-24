import Foundation
import Carbon.HIToolbox
import Cocoa

/// Service for detecting global hotkey press/release events
/// Uses CGEventTap to monitor key events system-wide
class HotkeyService {
    // MARK: - Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let stateLock = NSLock()
    private var isKeyDown = false
    private var settings = AppSettings.shared

    // Callbacks
    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void

    // Track modifier state to avoid key repeat
    private var lastModifierFlags: CGEventFlags = []

    // MARK: - Initialization

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    func start() {
        guard eventTap == nil else { return }

        // Check accessibility permission
        let trusted = AXIsProcessTrusted()
        NSLog("HotkeyService: AXIsProcessTrusted = %@", trusted ? "YES" : "NO")
        guard trusted else {
            NSLog("HotkeyService: No accessibility - cannot create event tap")
            return
        }

        // Create event tap for modifier key events
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue)

        // Create the event tap with a callback
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
                return service.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            NSLog("HotkeyService: FAILED to create event tap")
            return
        }
        NSLog("HotkeyService: Event tap created")

        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else {
            NSLog("HotkeyService: FAILED to create run loop source")
            return
        }
        NSLog("HotkeyService: Run loop source created")

        // Add to the MAIN run loop (important for GUI apps)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        NSLog("HotkeyService: Added to main run loop")

        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)

        // Verify it's enabled
        let isEnabled = CGEvent.tapIsEnabled(tap: eventTap)
        NSLog("HotkeyService: Event tap enabled = %@", isEnabled ? "YES" : "NO")
        NSLog("HotkeyService: Ready - hold Option key to record")
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        stateLock.lock()
        isKeyDown = false
        stateLock.unlock()

        print("HotkeyService: Stopped")
    }

    func updateHotkey(_ config: HotkeyConfig) {
        // Hotkey config is read from settings on each event
        // No need to restart the tap
        print("HotkeyService: Hotkey updated to \(config.displayName)")
    }

    // MARK: - Private Methods

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap disabled event - this can happen if callback takes too long
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("HotkeyService: Event tap was DISABLED - re-enabling")
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        // Only handle flags changed events for modifier keys
        guard type == .flagsChanged else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        NSLog("HotkeyService: flagsChanged keyCode=%d", keyCode)

        // Check if this is our configured hotkey
        let hotkeyConfig = settings.hotkeyConfig

        // Detect key down/up based on flag presence
        let isTargetKey = keyCode == hotkeyConfig.keyCode ||
                          isModifierKeyMatch(keyCode: keyCode, config: hotkeyConfig)

        if isTargetKey {
            let isNowDown = isModifierPressed(flags: flags, config: hotkeyConfig)

            // Thread-safe check-and-set for key state
            stateLock.lock()
            let wasDown = isKeyDown
            var shouldCallKeyDown = false
            var shouldCallKeyUp = false

            if isNowDown && !wasDown {
                isKeyDown = true
                shouldCallKeyDown = true
            } else if !isNowDown && wasDown {
                isKeyDown = false
                shouldCallKeyUp = true
            }
            stateLock.unlock()

            NSLog("HotkeyService: Target key! wasDown=%d isNowDown=%d", wasDown ? 1 : 0, isNowDown ? 1 : 0)

            if shouldCallKeyDown {
                // Key pressed
                NSLog("HotkeyService: KEY DOWN")
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyDown()
                }
            } else if shouldCallKeyUp {
                // Key released
                NSLog("HotkeyService: KEY UP")
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyUp()
                }
            }
        }

        lastModifierFlags = flags

        // Pass the event through (don't block it)
        return Unmanaged.passRetained(event)
    }

    private func isModifierKeyMatch(keyCode: UInt16, config: HotkeyConfig) -> Bool {
        // Map key codes to their modifier equivalents
        switch Int(keyCode) {
        case kVK_Option, kVK_RightOption:
            return config.keyCode == UInt16(kVK_Option) || config.keyCode == UInt16(kVK_RightOption)
        case kVK_Control, kVK_RightControl:
            return config.keyCode == UInt16(kVK_Control) || config.keyCode == UInt16(kVK_RightControl)
        case kVK_Shift, kVK_RightShift:
            return config.keyCode == UInt16(kVK_Shift) || config.keyCode == UInt16(kVK_RightShift)
        case kVK_Command, kVK_RightCommand:
            return config.keyCode == UInt16(kVK_Command) || config.keyCode == UInt16(kVK_RightCommand)
        default:
            return keyCode == config.keyCode
        }
    }

    private func isModifierPressed(flags: CGEventFlags, config: HotkeyConfig) -> Bool {
        switch Int(config.keyCode) {
        case kVK_Option, kVK_RightOption:
            return flags.contains(.maskAlternate)
        case kVK_Control, kVK_RightControl:
            return flags.contains(.maskControl)
        case kVK_Shift, kVK_RightShift:
            return flags.contains(.maskShift)
        case kVK_Command, kVK_RightCommand:
            return flags.contains(.maskCommand)
        default:
            return false
        }
    }

    private func promptForAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

// MARK: - Escape Key Handler

extension HotkeyService {
    /// Cancel current operation when Escape is pressed
    func enableEscapeCancel(onCancel: @escaping () -> Void) {
        // This would be implemented with an additional event tap for key events
        // For MVP, we'll handle this in the main app delegate
    }
}

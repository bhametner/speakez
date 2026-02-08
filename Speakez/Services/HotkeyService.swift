import Foundation
import Carbon.HIToolbox
import Cocoa
import os.log

/// Service for detecting global hotkey press/release events
/// Uses CGEventTap to monitor key events system-wide
class HotkeyService {
    // MARK: - Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let stateLock = NSLock()
    private var isKeyDown = false
    private var settings = AppSettings.shared
    
    /// Returns true if the hotkey service is actively listening
    var isActive: Bool {
        return eventTap != nil
    }

    // Callbacks
    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void
    private let onEscape: (() -> Void)?

    // Track modifier state to avoid key repeat
    private var lastModifierFlags: CGEventFlags = []

    // MARK: - Initialization

    init(onKeyDown: @escaping () -> Void, 
         onKeyUp: @escaping () -> Void,
         onEscape: (() -> Void)? = nil) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        self.onEscape = onEscape
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    func start() {
        guard eventTap == nil else { return }

        // Check accessibility permission
        let trusted = AXIsProcessTrusted()
        guard trusted else {
            Log.hotkey.info(" No accessibility permission")
            return
        }

        // Create event tap for modifier key events and regular keys (for Escape)
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue)

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
            Log.hotkey.info(" Failed to create event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else {
            Log.hotkey.info(" Failed to create run loop source")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        Log.hotkey.info(" Ready - hold Option key to record, Escape to cancel")
        Log.hotkey.info(" isActive = \(isActive)")
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        stateLock.lock()
        isKeyDown = false
        stateLock.unlock()

        Log.hotkey.info(" Stopped")
    }

    func updateHotkey(_ config: HotkeyConfig) {
        Log.hotkey.info(" Hotkey updated to \(config.displayName)")
    }

    // MARK: - Private Methods

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap disabled event
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        
        // Handle Escape key for canceling (keyDown event)
        if type == .keyDown && keyCode == UInt16(kVK_Escape) {
            stateLock.lock()
            let wasDown = isKeyDown
            stateLock.unlock()
            
            if wasDown {
                // Cancel recording
                DispatchQueue.main.async { [weak self] in
                    self?.onEscape?()
                }
                // Reset key state
                stateLock.lock()
                isKeyDown = false
                stateLock.unlock()
                
                // Don't consume the event, let it pass through
                return Unmanaged.passRetained(event)
            }
        }

        // Only handle flags changed events for modifier keys
        guard type == .flagsChanged else {
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let hotkeyConfig = settings.hotkeyConfig

        // Detect key down/up based on flag presence
        let isTargetKey = keyCode == hotkeyConfig.keyCode ||
                          isModifierKeyMatch(keyCode: keyCode, config: hotkeyConfig)

        if isTargetKey {
            let isNowDown = isModifierPressed(flags: flags, config: hotkeyConfig)

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

            if shouldCallKeyDown {
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyDown()
                }
            } else if shouldCallKeyUp {
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyUp()
                }
            }
        }

        lastModifierFlags = flags
        return Unmanaged.passRetained(event)
    }

    private func isModifierKeyMatch(keyCode: UInt16, config: HotkeyConfig) -> Bool {
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
}

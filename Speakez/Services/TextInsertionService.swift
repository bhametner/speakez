import Foundation
import AppKit
import Carbon.HIToolbox
import os.log

/// Service for inserting text at the cursor position in any application
/// Uses clipboard + Cmd+V approach for universal compatibility
class TextInsertionService {
    // MARK: - Properties

    private let pasteboard = NSPasteboard.general
    private var savedClipboardItems: [NSPasteboardItem]?
    private var savedChangeCount: Int = 0

    // Timing configuration
    private let pasteDelay: TimeInterval = 0.05  // 50ms delay before paste
    private let restoreDelay: TimeInterval = 0.1 // 100ms delay before restore

    // MARK: - Public Methods

    /// Insert text at the current cursor position
    /// - Parameter text: The text to insert
    /// Note: The transcription stays on the clipboard so you can Cmd+V again if needed
    func insertText(_ text: String) {
        guard !text.isEmpty else { return }
        guard AXIsProcessTrusted() else { return }

        // Copy text to clipboard (it stays there for manual paste if auto-paste fails)
        setClipboardText(text)

        // Simulate Cmd+V after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) { [weak self] in
            self?.simulatePaste()
        }
    }

    /// Insert text synchronously (blocking)
    /// - Parameter text: The text to insert
    func insertTextSync(_ text: String) {
        guard !text.isEmpty else { return }
        guard AXIsProcessTrusted() else {
            Log.textInsertion.info(" Accessibility permission required")
            return
        }

        saveClipboard()
        setClipboardText(text)

        Thread.sleep(forTimeInterval: pasteDelay)
        simulatePaste()

        Thread.sleep(forTimeInterval: restoreDelay)
        restoreClipboard()
    }

    // MARK: - Clipboard Operations

    private func saveClipboard() {
        savedChangeCount = pasteboard.changeCount

        // Save all pasteboard items
        savedClipboardItems = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            return newItem
        }
    }

    private func setClipboardText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func restoreClipboard() {
        // Check if clipboard was modified externally during the paste operation
        // If so, don't restore (user may have copied something else)
        if pasteboard.changeCount != savedChangeCount + 1 {
            Log.textInsertion.info(" Clipboard modified externally, skipping restore")
            return
        }

        guard let items = savedClipboardItems, !items.isEmpty else {
            // No previous content to restore
            return
        }

        pasteboard.clearContents()
        pasteboard.writeObjects(items)

        savedClipboardItems = nil
        Log.textInsertion.info(" Clipboard restored")
    }

    // MARK: - Keystroke Simulation

    private func simulatePaste() {
        // Create Cmd+V key down event
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            Log.textInsertion.info(" Failed to create event source")
            return
        }

        // V key code
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            Log.textInsertion.info(" Failed to create key down event")
            return
        }

        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            Log.textInsertion.info(" Failed to create key up event")
            return
        }

        // Add Command modifier
        keyDownEvent.flags = .maskCommand
        keyUpEvent.flags = .maskCommand

        // Post events
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)

        Log.textInsertion.info(" Paste simulated")
    }

    // MARK: - Alternative: Accessibility API Text Insertion

    /// Alternative method using Accessibility API (less reliable across apps)
    /// This is provided as a fallback but not recommended for general use
    func insertTextViaAccessibility(_ text: String) {
        guard AXIsProcessTrusted() else {
            Log.textInsertion.info(" Accessibility permission required")
            return
        }

        // Get the frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let pid = frontApp.processIdentifier as pid_t? else {
            Log.textInsertion.info(" Could not get frontmost application")
            return
        }

        let appElement = AXUIElementCreateApplication(pid)

        // Get focused element
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard result == .success, let element = focusedElement else {
            Log.textInsertion.info(" Could not get focused element")
            return
        }

        let axElement = element as! AXUIElement

        // Try to set the value
        let setResult = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, text as CFTypeRef)

        if setResult == .success {
            Log.textInsertion.info(" Text inserted via Accessibility API")
        } else {
            Log.textInsertion.info(" Accessibility API insertion failed, falling back to clipboard")
            insertText(text)
        }
    }

    // MARK: - Permissions

    private func promptForAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Check if accessibility permission is granted
    static var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }
}

// MARK: - Typing Simulation Extension

extension TextInsertionService {
    /// Simulate typing character by character (slower but more compatible with some apps)
    /// - Parameters:
    ///   - text: The text to type
    ///   - delay: Delay between keystrokes in seconds
    func simulateTyping(_ text: String, delay: TimeInterval = 0.01) {
        guard AXIsProcessTrusted() else {
            Log.textInsertion.info(" Accessibility permission required")
            return
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        for (index, character) in text.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay * Double(index)) {
                self.typeCharacter(character, source: source)
            }
        }
    }

    private func typeCharacter(_ character: Character, source: CGEventSource) {
        let string = String(character)

        // Create a key event and set the unicode string
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            return
        }

        // Use unicode string entry
        var unichar = Array(string.utf16)
        keyDown.keyboardSetUnicodeString(stringLength: unichar.count, unicodeString: &unichar)
        keyUp.keyboardSetUnicodeString(stringLength: unichar.count, unicodeString: &unichar)

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

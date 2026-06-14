import Foundation
import AppKit
import CoreGraphics

class PasteManager {
    static let shared = PasteManager()

    private init() {}

    /// Paste the given text to the current frontmost application
    /// by temporarily writing it to the pasteboard and simulating Cmd+V.
    func paste(text: String) {
        let pb = NSPasteboard.general

        // Save the current pasteboard items to restore later
        let savedItems = pb.pasteboardItems

        // Pause clipboard monitoring
        ClipboardMonitor.shared.pauseWhilePasting {
            // Clear and set our content
            pb.clearContents()
            pb.setString(text, forType: .string)

            // Wait a tiny bit for the pasteboard to be ready
            Thread.sleep(forTimeInterval: 0.05)

            // Simulate Cmd+V
            let source = CGEventSource(stateID: .combinedSessionState)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = 'v'
            keyDown?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            keyUp?.flags = .maskCommand
            keyUp?.post(tap: .cghidEventTap)

            // Give the paste time to complete
            Thread.sleep(forTimeInterval: 0.05)

            // Restore original clipboard contents
            pb.clearContents()
            if let savedItems = savedItems {
                pb.writeObjects(savedItems)
            }
        }
    }
}
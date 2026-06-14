import Foundation
import AppKit
import CoreGraphics

class PasteManager {
    static let shared = PasteManager()

    private init() {}

    /// Paste the given text to the current frontmost application
    /// by writing it to the pasteboard and simulating Cmd+V.
    func paste(text: String) {
        let pb = NSPasteboard.general

        // Set our content on the pasteboard
        pb.clearContents()
        pb.setString(text, forType: .string)

        // Wait for the pasteboard to be ready
        Thread.sleep(forTimeInterval: 0.05)

        // Simulate Cmd+V
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = 'v'
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)

        // Give the paste time to start before resuming monitoring
        Thread.sleep(forTimeInterval: 0.05)

        // Resume clipboard monitoring
        ClipboardMonitor.shared.resume()
    }
}

import Foundation
import AppKit

class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var isPasting = false

    private init() {}

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Temporarily pause monitoring (used during paste operations)
    func pauseWhilePasting(_ block: () -> Void) {
        isPasting = true
        block()
        // Reset changeCount so we don't pick up our own writes
        lastChangeCount = NSPasteboard.general.changeCount
        isPasting = false
    }

    /// Pause monitoring for async paste operations.
    /// Must call resume() after the paste completes.
    func pauseUntilNextPaste() {
        isPasting = true
    }

    /// Resume monitoring after an async paste operation.
    func resume() {
        lastChangeCount = NSPasteboard.general.changeCount
        isPasting = false
    }

    private func check() {
        guard !isPasting else { return }

        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let items = pb.pasteboardItems else { return }

        for item in items {
            if let text = item.string(forType: .string) {
                HistoryManager.shared.add(text: text)
                break
            }
        }
    }
}
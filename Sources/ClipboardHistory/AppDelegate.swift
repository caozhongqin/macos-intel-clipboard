import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "📋"
            button.font = NSFont.systemFont(ofSize: 14)
        }

        // Setup menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示剪贴板历史", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "清空历史", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Start clipboard monitoring
        ClipboardMonitor.shared.start()

        // Register global hotkey
        HotKeyManager.shared.onHotKey = { [weak self] in
            self?.toggleWindow()
        }
        _ = HotKeyManager.shared.register()

        // Monitor keyboard events when our window is active
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if HistoryWindowController.shared.handleKeyEvent(event) {
                return nil // consumed
            }
            return event
        }
    }

    @objc private func toggleWindow() {
        HistoryWindowController.shared.toggle()
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "确认清空所有剪贴板历史？"
        alert.informativeText = "此操作不可撤销。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            HistoryManager.shared.clear()
            HistoryWindowController.shared.reloadData()
        }
    }
}
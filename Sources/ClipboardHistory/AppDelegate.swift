import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility permissions (needed for simulating Cmd+V)
        checkAccessibilityPermissions()

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

    private func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            // The system will show a prompt asking the user to grant Accessibility permissions.
            // Show an additional alert to explain why it's needed.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = "剪贴板历史需要「辅助功能」权限才能模拟 Cmd+V 粘贴操作。\n\n请前往「系统设置 → 隐私与安全性 → 辅助功能」中，将本应用添加到允许列表。\n\n添加后，请重新启动本应用。"
                alert.addButton(withTitle: "好的")
                alert.alertStyle = .informational
                alert.runModal()
            }
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
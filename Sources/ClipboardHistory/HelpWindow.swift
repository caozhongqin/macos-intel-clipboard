import Foundation
import AppKit

class HelpWindow {
    static let shared = HelpWindow()
    private var window: NSWindow?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "使用说明"
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.center()

        // Build attributed content
        let content = NSMutableAttributedString()

        func appendSection(_ title: String) {
            content.append(NSAttributedString(string: "\n\(title)\n", attributes: [
                .font: NSFont.boldSystemFont(ofSize: 15),
                .foregroundColor: NSColor.labelColor
            ]))
        }
        func appendText(_ text: String) {
            content.append(NSAttributedString(string: "\(text)\n", attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
        }
        func appendShortcut(_ key: String, _ desc: String) {
            let line = NSMutableAttributedString()
            line.append(NSAttributedString(string: "\(key)\t\(desc)\n", attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
            // Apply monospace font to the key part (before tab)
            line.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ], range: NSRange(location: 0, length: key.count))
            // Add tab stop for alignment
            let paraStyle = NSMutableParagraphStyle()
            paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: 160, options: [:])]
            line.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: line.length))
            content.append(line)
        }

        appendSection("📋 基本使用")
        appendText("系统剪贴板历史会自动记录您复制的内容。按 Cmd+Shift+V 打开主窗口查看和搜索历史记录。双击项目或按 ⌘Enter 粘贴到当前应用。")
        appendSection("🗂 分类系统")
        appendText("「剪贴板历史」是系统默认分类，自动保存最近 50 条剪贴板记录。您可以创建自定义分类来管理常用的代码片段和文本。")
        appendSection("📝 自定义分类")
        appendText("• 点击分类下拉菜单选择「管理分类…」")
        appendText("• 点击「新建」创建自定义分类")
        appendText("• 选中分类后，点击「+」按钮添加代码块")
        appendText("• 右键点击项目可编辑、删除或移动到其他分类")
        appendText("• 拖拽项目可调整排序")
        appendSection("⌨️ 快捷键一览")
        appendShortcut("Cmd+Shift+V", "打开/切换主窗口")
        appendShortcut("⌘Enter", "粘贴选中项")
        appendShortcut("⌘Delete", "删除选中项")
        appendShortcut("Escape", "清空搜索 / 关闭窗口")
        appendShortcut("Tab", "切换分类")
        appendShortcut("↑  ↓", "选择上一个/下一个")
        appendShortcut("双击", "粘贴选中项")
        appendSection("ℹ️ 关于")
        appendText("剪贴板历史 v1.0")
        appendText("需要在「系统设置 → 隐私与安全性 → 辅助功能」中授权才能使用自动粘贴功能。")

        // Text view — use a large height, scroll view clips and scrolls as needed
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 460, height: 1200))
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textStorage?.setAttributedString(content)

        // Scroll view with autoresizing
        let scrollView = NSScrollView(frame: panel.contentView!.bounds.insetBy(dx: 0, dy: 8))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]

        panel.contentView?.addSubview(scrollView)

        window = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
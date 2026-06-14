import Foundation
import AppKit

class HistoryWindowController: NSObject {
    static let shared = HistoryWindowController()

    private let window: NSPanel
    private let tableView: NSTableView
    private let scrollView: NSScrollView
    private let visualEffectView: NSVisualEffectView

    private var items: [HistoryItem] = []
    private var isVisible = false
    private var previousApp: NSRunningApplication?

    private override init() {
        // Create the floating panel
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 460),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Visual effect view (vibrancy)
        visualEffectView = NSVisualEffectView(frame: window.contentRect(forFrameRect: window.frame))
        visualEffectView.material = .popover
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true

        // Create table column first (doesn't need self)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        column.title = ""
        column.isEditable = false
        column.width = 400

        // Create table view (doesn't need self for creation)
        tableView = NSTableView()
        tableView.wantsLayer = true
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.selectionHighlightStyle = .regular
        tableView.addTableColumn(column)

        // Scroll view wrapping the table
        scrollView = NSScrollView(frame: visualEffectView.bounds)
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        super.init()

        // Now we can use self after super.init
        tableView.target = self
        tableView.doubleAction = #selector(doubleClickRow)

        // Configure window
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // Layout
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false

        window.contentView?.addSubview(visualEffectView)
        visualEffectView.addSubview(scrollView)

        if let contentView = window.contentView {
            NSLayoutConstraint.activate([
                visualEffectView.topAnchor.constraint(equalTo: contentView.topAnchor),
                visualEffectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                visualEffectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                visualEffectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

                scrollView.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 24),
                scrollView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 8),
                scrollView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -8),
                scrollView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -8)
            ])
        }

        tableView.dataSource = self
        tableView.delegate = self

        // Add a visual indicator for the empty state
        let emptyField = NSTextField(labelWithString: "暂无剪贴板历史")
        emptyField.alignment = .center
        emptyField.textColor = .secondaryLabelColor
        emptyField.font = NSFont.systemFont(ofSize: 14)
        emptyField.frame = NSRect(x: 0, y: 0, width: 200, height: 20)
        emptyField.isHidden = true
        emptyField.tag = 999
        scrollView.addSubview(emptyField)
    }

    // MARK: - Show / Hide

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        // Remember which app was frontmost before we show our panel
        previousApp = NSWorkspace.shared.frontmostApplication

        reloadData()
        positionWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true

        // Focus on table and select first row
        window.makeFirstResponder(tableView)
        if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func hide() {
        window.orderOut(nil)
        isVisible = false
    }

    // MARK: - Reload

    func reloadData() {
        items = HistoryManager.shared.recentItems(limit: 30)
        tableView.reloadData()

        // Show/hide empty state
        if let emptyField = scrollView.viewWithTag(999) as? NSTextField {
            emptyField.isHidden = !items.isEmpty
            emptyField.frame = NSRect(
                x: (scrollView.bounds.width - 200) / 2,
                y: scrollView.bounds.height / 2 - 10,
                width: 200,
                height: 20
            )
        }
    }

    // MARK: - Positioning

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let windowRect = window.frame

        let x = screenRect.origin.x + (screenRect.width - windowRect.width) / 2
        let y = screenRect.origin.y + (screenRect.height - windowRect.height) / 2

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Actions

    @objc private func doubleClickRow() {
        performPaste()
    }

    func performPaste() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < items.count else { return }
        let item = items[selectedRow]
        hide()

        // Switch back to the previous app
        guard let app = previousApp else { return }
        app.activate(options: .activateIgnoringOtherApps)

        // Protect clipboard monitoring from detecting our change while we're async
        ClipboardMonitor.shared.pauseUntilNextPaste()

        // Use async dispatch to let the runloop process app activation
        // before we post keyboard events. Thread.sleep() would block the runloop.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [item] in
            PasteManager.shared.paste(text: item.text)
        }
    }

    func deleteSelected() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < items.count else { return }
        let item = items[selectedRow]
        HistoryManager.shared.remove(id: item.id)
        reloadData()

        // Select the same row or previous
        let newRow = min(selectedRow, items.count - 1)
        if newRow >= 0 {
            tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        }
    }
}

// MARK: - NSTableViewDataSource

extension HistoryWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }
}

// MARK: - NSTableViewDelegate

extension HistoryWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("cell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView ?? {
            let newCell = NSTableCellView()
            newCell.identifier = identifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.cell?.lineBreakMode = .byTruncatingTail
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.textColor = .labelColor
            textField.maximumNumberOfLines = 2
            newCell.addSubview(textField)
            newCell.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 12),
                textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -12),
                textField.centerYAnchor.constraint(equalTo: newCell.centerYAnchor)
            ])

            return newCell
        }()

        let item = items[row]
        cell.textField?.stringValue = item.text
        cell.textField?.textColor = .labelColor
        cell.toolTip = item.text

        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("rowView")
        let rowView = tableView.makeView(withIdentifier: identifier, owner: nil) as? CustomRowView ?? {
            let rv = CustomRowView()
            rv.identifier = identifier
            return rv
        }()
        return rowView
    }
}

// MARK: - Custom Row View

class CustomRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        let selectionRect = bounds.insetBy(dx: 4, dy: 2)
        let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
        NSColor.selectedContentBackgroundColor.setFill()
        path.fill()
    }

    override func drawBackground(in dirtyRect: NSRect) {
        // Transparent
    }
}

// MARK: - Keyboard Navigation

extension HistoryWindowController {
    /// Handle key events. Call this from the application's key event handler.
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }

        switch event.keyCode {
        case 36: // Return
            performPaste()
            return true
        case 53: // Escape
            hide()
            return true
        case 51: // Delete
            deleteSelected()
            return true
        case 125, 126: // Down / Up
            // These are handled by NSTableView natively
            return false
        default:
            return false
        }
    }
}
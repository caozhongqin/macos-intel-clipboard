import Foundation
import AppKit

class HistoryWindowController: NSObject {
    static let shared = HistoryWindowController()

    private let window: NSPanel
    private let tableView: NSTableView
    private let scrollView: NSScrollView
    private let visualEffectView: NSVisualEffectView
    private let topRowView: NSView
    private let searchField: NSSearchField
    private let categoryPopUp: NSPopUpButton
    private let addButton: NSButton

    private var currentCategoryId: UUID?
    private var allItems: [HistoryItem] = []
    private var filteredItems: [HistoryItem] = []
    private var isVisible = false
    private var previousApp: NSRunningApplication?

    private override init() {
        // Create the floating panel
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
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

        // Top row: search field + category popup
        topRowView = NSView()
        topRowView.translatesAutoresizingMaskIntoConstraints = false

        // Create search field
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "搜索..."

        // Create category popup button
        categoryPopUp = NSPopUpButton()
        categoryPopUp.translatesAutoresizingMaskIntoConstraints = false
        categoryPopUp.bezelStyle = .rounded
        categoryPopUp.pullsDown = false

        // Add button (for custom categories)
        addButton = NSButton(title: "+", target: nil, action: nil)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.bezelStyle = .rounded
        addButton.isHidden = true
        addButton.toolTip = "添加代码块"

        // Create table column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        column.title = ""
        column.isEditable = false
        column.width = 440

        // Create table view
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

        // Setup targets and delegates after super.init
        tableView.target = self
        tableView.doubleAction = #selector(doubleClickRow)
        tableView.menu = createContextMenu()
        searchField.target = self
        searchField.action = #selector(searchAction)
        searchField.delegate = self

        categoryPopUp.target = self
        categoryPopUp.action = #selector(categoryChanged)
        addButton.target = self
        addButton.action = #selector(addItem)

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
        visualEffectView.addSubview(topRowView)
        topRowView.addSubview(searchField)
        topRowView.addSubview(categoryPopUp)
        topRowView.addSubview(addButton)
        visualEffectView.addSubview(scrollView)

        if let contentView = window.contentView {
            NSLayoutConstraint.activate([
                visualEffectView.topAnchor.constraint(equalTo: contentView.topAnchor),
                visualEffectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                visualEffectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                visualEffectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

                // Top row
                topRowView.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 12),
                topRowView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 12),
                topRowView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -12),
                topRowView.heightAnchor.constraint(equalToConstant: 24),

                // Search field
                searchField.leadingAnchor.constraint(equalTo: topRowView.leadingAnchor),
                searchField.centerYAnchor.constraint(equalTo: topRowView.centerYAnchor),
                searchField.trailingAnchor.constraint(equalTo: categoryPopUp.leadingAnchor, constant: -8),

                // Category popup
                categoryPopUp.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -4),
                categoryPopUp.centerYAnchor.constraint(equalTo: topRowView.centerYAnchor),
                categoryPopUp.widthAnchor.constraint(equalToConstant: 140),

                // Add button
                addButton.trailingAnchor.constraint(equalTo: topRowView.trailingAnchor),
                addButton.centerYAnchor.constraint(equalTo: topRowView.centerYAnchor),
                addButton.widthAnchor.constraint(equalToConstant: 28),
                addButton.heightAnchor.constraint(equalToConstant: 24),

                // Table scroll view
                scrollView.topAnchor.constraint(equalTo: topRowView.bottomAnchor, constant: 8),
                scrollView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 8),
                scrollView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -8),
                scrollView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -8)
            ])
        }

        tableView.dataSource = self
        tableView.delegate = self

        // Empty state label
        let emptyField = NSTextField(labelWithString: "暂无内容")
        emptyField.alignment = .center
        emptyField.textColor = .secondaryLabelColor
        emptyField.font = NSFont.systemFont(ofSize: 14)
        emptyField.frame = NSRect(x: 0, y: 0, width: 200, height: 20)
        emptyField.isHidden = true
        emptyField.tag = 999
        scrollView.addSubview(emptyField)
    }

    // MARK: - Category Popup

    private func rebuildCategoryPopup() {
        categoryPopUp.removeAllItems()
        let categories = CategoryManager.shared.categories.sorted { $0.sortOrder < $1.sortOrder }
        for cat in categories {
            categoryPopUp.addItem(withTitle: cat.name)
            categoryPopUp.lastItem?.representedObject = cat.id
        }
        categoryPopUp.menu?.addItem(.separator())
        categoryPopUp.addItem(withTitle: "管理分类…")
        categoryPopUp.lastItem?.representedObject = nil
    }

    private func selectCategory(id: UUID) {
        rebuildCategoryPopup()
        for i in 0..<categoryPopUp.numberOfItems {
            if let itemId = categoryPopUp.item(at: i)?.representedObject as? UUID, itemId == id {
                categoryPopUp.selectItem(at: i)
                break
            }
        }
        currentCategoryId = id

        if let cat = CategoryManager.shared.categories.first(where: { $0.id == id }) {
            addButton.isHidden = cat.isDefault
        }

        searchField.stringValue = ""
        reloadData()
    }

    // MARK: - Context Menu

    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        let editItem = NSMenuItem(title: "编辑", action: #selector(editSelectedItem), keyEquivalent: "")
        editItem.target = self

        let moveMenu = NSMenu(title: "移动到…")
        let moveItem = NSMenuItem(title: "移动到…", action: nil, keyEquivalent: "")
        moveItem.submenu = moveMenu

        let deleteItem = NSMenuItem(title: "删除", action: #selector(deleteSelected), keyEquivalent: "")
        deleteItem.target = self

        menu.addItem(editItem)
        menu.addItem(moveItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(deleteItem)
        return menu
    }

    private func rebuildContextMenu() {
        guard let menu = tableView.menu,
              let moveItem = menu.item(at: 1),
              let moveMenu = moveItem.submenu else { return }
        moveMenu.removeAllItems()
        let currentId = currentCategoryId
        let categories = CategoryManager.shared.categories.sorted { $0.sortOrder < $1.sortOrder }
        for cat in categories where cat.id != currentId {
            let item = NSMenuItem(title: cat.name, action: #selector(moveSelectedTo(_:)), keyEquivalent: "")
            item.representedObject = cat.id
            item.target = self
            moveMenu.addItem(item)
        }
    }

    // MARK: - Show / Hide

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication

        if currentCategoryId == nil, let defaultCat = CategoryManager.shared.defaultCategory {
            selectCategory(id: defaultCat.id)
        } else if let currentId = currentCategoryId {
            selectCategory(id: currentId)
        }

        positionWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true

        window.makeFirstResponder(tableView)
        if !filteredItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func hide() {
        window.orderOut(nil)
        isVisible = false
    }

    // MARK: - Reload

    func reloadData() {
        guard let catId = currentCategoryId,
              let cat = CategoryManager.shared.categories.first(where: { $0.id == catId }) else {
            allItems = []
            filteredItems = []
            tableView.reloadData()
            return
        }
        allItems = cat.items
        applyFilter()
    }

    private func applyFilter() {
        let searchText = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if searchText.isEmpty {
            filteredItems = allItems
        } else {
            filteredItems = allItems.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
        tableView.reloadData()

        if let emptyField = scrollView.viewWithTag(999) as? NSTextField {
            emptyField.isHidden = !filteredItems.isEmpty
            emptyField.stringValue = filteredItems.isEmpty && !allItems.isEmpty
                ? "未找到匹配结果"
                : "暂无内容"
            emptyField.frame = NSRect(
                x: (scrollView.bounds.width - 200) / 2,
                y: scrollView.bounds.height / 2 - 10,
                width: 200,
                height: 20
            )
        }

        if !filteredItems.isEmpty {
            if tableView.selectedRow < 0 || tableView.selectedRow >= filteredItems.count {
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            }
        }
    }

    // MARK: - Actions

    @objc private func categoryChanged(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        if selectedIndex >= 0,
           let item = sender.item(at: selectedIndex),
           item.representedObject == nil {
            showCategoryManagement()
            if let currentId = currentCategoryId {
                selectCategory(id: currentId)
            }
            return
        }

        guard let itemId = sender.selectedItem?.representedObject as? UUID else { return }
        currentCategoryId = itemId

        if let cat = CategoryManager.shared.categories.first(where: { $0.id == itemId }) {
            addButton.isHidden = cat.isDefault
        }

        searchField.stringValue = ""
        reloadData()
        rebuildContextMenu()

        window.makeFirstResponder(tableView)
        if !filteredItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    @objc private func addItem() {
        guard let catId = currentCategoryId,
              let cat = CategoryManager.shared.categories.first(where: { $0.id == catId }),
              !cat.isDefault else { return }

        let (text, accepted) = showMultilineInputDialog(
            title: "添加代码块",
            message: "输入代码内容：",
            placeholder: "输入代码或文本...",
            defaultValue: ""
        )
        if accepted, !text.isEmpty {
            _ = CategoryManager.shared.addItem(to: catId, text: text)
            reloadData()
            if !filteredItems.isEmpty {
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            }
        }
    }

    @objc private func doubleClickRow() {
        performPaste()
    }

    func performPaste() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < filteredItems.count else { return }
        let item = filteredItems[selectedRow]
        hide()

        guard let app = previousApp else { return }
        app.activate(options: .activateIgnoringOtherApps)
        ClipboardMonitor.shared.pauseUntilNextPaste()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [item] in
            PasteManager.shared.paste(text: item.text)
        }
    }

    @objc func deleteSelected() {
        guard let catId = currentCategoryId else { return }
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < filteredItems.count else { return }
        let item = filteredItems[selectedRow]

        _ = CategoryManager.shared.deleteItem(from: catId, itemId: item.id)
        reloadData()

        let newRow = min(selectedRow, filteredItems.count - 1)
        if newRow >= 0 {
            tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        }
    }

    @objc private func editSelectedItem() {
        guard let catId = currentCategoryId else { return }
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < filteredItems.count else { return }
        let item = filteredItems[selectedRow]

        let (newText, accepted) = showMultilineInputDialog(
            title: "编辑代码块",
            message: "修改代码内容：",
            placeholder: nil,
            defaultValue: item.text
        )
        if accepted, !newText.isEmpty {
            _ = CategoryManager.shared.updateItem(in: catId, itemId: item.id, newText: newText)
            reloadData()
        }
    }

    @objc private func moveSelectedTo(_ sender: NSMenuItem) {
        guard let sourceCatId = currentCategoryId,
              let targetCatId = sender.representedObject as? UUID else { return }
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < filteredItems.count else { return }
        let item = filteredItems[selectedRow]

        _ = CategoryManager.shared.moveItem(itemId: item.id, from: sourceCatId, to: targetCatId)
        reloadData()

        if !filteredItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    @objc private func searchAction(_ sender: NSSearchField) {
        applyFilter()
    }

    // MARK: - Multiline Input Dialog

    /// Shows a dialog with a multiline text view (NSTextView) instead of a single-line NSTextField.
    /// Returns the entered text and whether the user accepted.
    private func showMultilineInputDialog(title: String, message: String, placeholder: String?, defaultValue: String) -> (String, Bool) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 120))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 360, height: 120))
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.string = defaultValue
        textView.isEditable = true
        textView.isSelectable = true
        textView.autoresizingMask = [.width, .height]

        if defaultValue.isEmpty {
            textView.string = ""
        }

        scrollView.documentView = textView

        alert.accessoryView = scrollView

        // Make text view the first responder
        alert.window.initialFirstResponder = textView

        let response = alert.runModal()
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)

        return (text, response == .alertFirstButtonReturn)
    }

    // MARK: - Category Management Sheet

    private func showCategoryManagement() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "管理分类"
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true

        // Table for category list
        let catTable = NSTableView()
        catTable.wantsLayer = true
        catTable.backgroundColor = .clear
        catTable.headerView = nil
        catTable.rowHeight = 32
        catTable.intercellSpacing = NSSize(width: 0, height: 1)
        catTable.selectionHighlightStyle = .regular
        let catCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("catName"))
        catCol.title = ""
        catCol.isEditable = false
        catCol.width = 320
        catTable.addTableColumn(catCol)

        let catScroll = NSScrollView(frame: NSRect(x: 0, y: 44, width: 360, height: 276))
        catScroll.documentView = catTable
        catScroll.hasVerticalScroller = false
        catScroll.drawsBackground = false
        catScroll.autohidesScrollers = true
        catScroll.translatesAutoresizingMaskIntoConstraints = false

        let addBtn = NSButton(title: "新建", target: nil, action: nil)
        addBtn.bezelStyle = .rounded
        addBtn.translatesAutoresizingMaskIntoConstraints = false

        let renameBtn = NSButton(title: "重命名", target: nil, action: nil)
        renameBtn.bezelStyle = .rounded
        renameBtn.translatesAutoresizingMaskIntoConstraints = false

        let deleteBtn = NSButton(title: "删除", target: nil, action: nil)
        deleteBtn.bezelStyle = .rounded
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false

        let closeBtn = NSButton(title: "完成", target: nil, action: nil)
        closeBtn.bezelStyle = .rounded
        closeBtn.keyEquivalent = "\r"
        closeBtn.translatesAutoresizingMaskIntoConstraints = false

        let buttonRow = NSView()
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        panel.contentView?.addSubview(catScroll)
        panel.contentView?.addSubview(buttonRow)
        buttonRow.addSubview(addBtn)
        buttonRow.addSubview(renameBtn)
        buttonRow.addSubview(deleteBtn)
        buttonRow.addSubview(closeBtn)

        if let contentView = panel.contentView {
            NSLayoutConstraint.activate([
                catScroll.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                catScroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
                catScroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
                catScroll.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -8),

                buttonRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
                buttonRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
                buttonRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
                buttonRow.heightAnchor.constraint(equalToConstant: 28),

                addBtn.leadingAnchor.constraint(equalTo: buttonRow.leadingAnchor),
                addBtn.centerYAnchor.constraint(equalTo: buttonRow.centerYAnchor),
                renameBtn.leadingAnchor.constraint(equalTo: addBtn.trailingAnchor, constant: 8),
                renameBtn.centerYAnchor.constraint(equalTo: buttonRow.centerYAnchor),
                deleteBtn.leadingAnchor.constraint(equalTo: renameBtn.trailingAnchor, constant: 8),
                deleteBtn.centerYAnchor.constraint(equalTo: buttonRow.centerYAnchor),
                closeBtn.trailingAnchor.constraint(equalTo: buttonRow.trailingAnchor),
                closeBtn.centerYAnchor.constraint(equalTo: buttonRow.centerYAnchor)
            ])
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Data source
        let dataSource = CategoryManagementDataSource(tableView: catTable, panel: panel)
        catTable.dataSource = dataSource
        catTable.delegate = dataSource
        dataSource.reload()

        addBtn.target = dataSource
        addBtn.action = #selector(CategoryManagementDataSource.addCategory)
        renameBtn.target = dataSource
        renameBtn.action = #selector(CategoryManagementDataSource.renameCategory)
        deleteBtn.target = dataSource
        deleteBtn.action = #selector(CategoryManagementDataSource.deleteCategory)
        closeBtn.target = dataSource
        closeBtn.action = #selector(CategoryManagementDataSource.closePanel)

        objc_setAssociatedObject(panel, "dataSource", dataSource, .OBJC_ASSOCIATION_RETAIN)
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
}

// MARK: - Category Management Data Source

class CategoryManagementDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var categories: [Category] = []
    let tableView: NSTableView
    let panel: NSPanel

    init(tableView: NSTableView, panel: NSPanel) {
        self.tableView = tableView
        self.panel = panel
    }

    func reload() {
        categories = CategoryManager.shared.categories.sorted { $0.sortOrder < $1.sortOrder }
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { categories.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("catCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView ?? {
            let newCell = NSTableCellView()
            newCell.identifier = identifier
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = NSFont.systemFont(ofSize: 13)
            newCell.addSubview(textField)
            newCell.textField = textField
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 12),
                textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -12),
                textField.centerYAnchor.constraint(equalTo: newCell.centerYAnchor)
            ])
            return newCell
        }()

        let cat = categories[row]
        if cat.isDefault {
            cell.textField?.stringValue = "\(cat.name) (系统)"
            cell.textField?.textColor = .secondaryLabelColor
        } else {
            cell.textField?.stringValue = cat.name
            cell.textField?.textColor = .labelColor
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        !categories[row].isDefault
    }

    // MARK: - Actions

    @objc func addCategory() {
        let alert = NSAlert()
        alert.messageText = "新建分类"
        alert.informativeText = "输入分类名称："
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 20))
        textField.placeholderString = "分类名称..."
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                _ = CategoryManager.shared.createCategory(name: name)
                reload()
            }
        }
    }

    @objc func renameCategory() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < categories.count, !categories[selectedRow].isDefault else { return }
        let cat = categories[selectedRow]

        let alert = NSAlert()
        alert.messageText = "重命名分类"
        alert.informativeText = "输入新名称："
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 20))
        textField.stringValue = cat.name
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty {
                CategoryManager.shared.renameCategory(id: cat.id, newName: newName)
                reload()
            }
        }
    }

    @objc func deleteCategory() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < categories.count, !categories[selectedRow].isDefault else { return }
        let cat = categories[selectedRow]

        let alert = NSAlert()
        alert.messageText = "删除分类「\(cat.name)」？"
        alert.informativeText = "该分类下的所有代码块将被永久删除。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            CategoryManager.shared.deleteCategory(id: cat.id)
            reload()
        }
    }

    @objc func closePanel() {
        panel.close()
    }
}

// MARK: - NSTableViewDataSource

extension HistoryWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredItems.count
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard row >= 0, row < filteredItems.count else { return nil }
        let item = filteredItems[row]
        let pbItem = NSPasteboardItem()
        pbItem.setString(item.id.uuidString, forType: .string)
        return pbItem
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above { return .move }
        return []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let catId = currentCategoryId else { return false }
        guard let pbItem = info.draggingPasteboard.pasteboardItems?.first,
              let idString = pbItem.string(forType: .string),
              let _ = UUID(uuidString: idString) else { return false }

        var currentIds = filteredItems.map(\.id.uuidString)
        guard let fromIndex = currentIds.firstIndex(of: idString) else { return false }

        currentIds.remove(at: fromIndex)
        currentIds.insert(idString, at: row)

        let uuidIds = currentIds.compactMap { UUID(uuidString: $0) }
        CategoryManager.shared.updateItemOrder(in: catId, itemIds: uuidIds)
        reloadData()
        return true
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

        let item = filteredItems[row]
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

// MARK: - NSSearchFieldDelegate

extension HistoryWindowController: NSSearchFieldDelegate {
    func searchFieldDidStartSearching(_ sender: NSSearchField) {}
    func searchFieldDidEndSearching(_ sender: NSSearchField) {}
}

// MARK: - Keyboard Navigation

extension HistoryWindowController {
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }

        // If the key window is not our panel (e.g., an NSAlert modal dialog is showing),
        // let all keys pass through so text input works normally.
        guard NSApp.keyWindow === window else { return false }

        switch event.keyCode {
        case 36: // Return — require Command modifier to avoid conflict with text editing
            if event.modifierFlags.contains(.command) {
                performPaste()
                return true
            }
            return false
        case 53: // Escape
            if !searchField.stringValue.isEmpty {
                searchField.stringValue = ""
                applyFilter()
                return true
            }
            hide()
            return true
        case 51: // Delete — require Command modifier to avoid conflict with text editing
            if event.modifierFlags.contains(.command) {
                deleteSelected()
                return true
            }
            return false
        case 48: // Tab
            if let currentId = currentCategoryId {
                let categories = CategoryManager.shared.categories.sorted { $0.sortOrder < $1.sortOrder }
                if let index = categories.firstIndex(where: { $0.id == currentId }) {
                    let nextIndex = (index + 1) % categories.count
                    selectCategory(id: categories[nextIndex].id)
                    rebuildContextMenu()
                }
            }
            return true
        case 125, 126: // Down / Up
            return false
        default:
            return false
        }
    }
}
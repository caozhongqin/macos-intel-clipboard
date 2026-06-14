import Foundation
import AppKit

class CategoryManager {
    static let shared = CategoryManager()

    private(set) var categories: [Category] = []

    private init() {
        load()
        ensureDefaultCategory()
    }

    // MARK: - Default Category

    /// The default category for system clipboard history
    var defaultCategory: Category? {
        categories.first(where: { $0.isDefault })
    }

    private func ensureDefaultCategory() {
        if categories.contains(where: { $0.isDefault }) { return }

        let defaultCat = Category(
            id: UUID(),
            name: "剪贴板历史",
            isDefault: true,
            sortOrder: 0,
            items: []
        )
        categories.insert(defaultCat, at: 0)
        save()
    }

    // MARK: - Category CRUD

    /// All categories except the default one (for display in management UI)
    var customCategories: [Category] {
        categories.filter { !$0.isDefault }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func createCategory(name: String) -> Category {
        let maxOrder = categories.map(\.sortOrder).max() ?? 0
        let cat = Category(
            id: UUID(),
            name: name,
            isDefault: false,
            sortOrder: maxOrder + 1,
            items: []
        )
        categories.append(cat)
        save()
        return cat
    }

    func renameCategory(id: UUID, newName: String) {
        guard let index = categories.firstIndex(where: { $0.id == id }),
              !categories[index].isDefault else { return }
        categories[index].name = newName
        save()
    }

    func deleteCategory(id: UUID) {
        guard let index = categories.firstIndex(where: { $0.id == id }),
              !categories[index].isDefault else { return }
        categories.remove(at: index)
        save()
    }

    func updateCategoryOrder(ids: [UUID]) {
        for (order, id) in ids.enumerated() {
            if let index = categories.firstIndex(where: { $0.id == id }) {
                categories[index].sortOrder = order
            }
        }
        save()
    }

    // MARK: - Code Block CRUD (inside custom categories)

    func addItem(to categoryId: UUID, text: String) -> HistoryItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }),
              !categories[catIndex].isDefault else { return nil }

        // Remove duplicate in the same category
        categories[catIndex].items.removeAll { $0.text == trimmed }

        let newItem = HistoryItem(id: UUID(), text: trimmed, timestamp: Date())
        categories[catIndex].items.insert(newItem, at: 0)
        save()
        return newItem
    }

    func updateItem(in categoryId: UUID, itemId: UUID, newText: String) -> Bool {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }),
              let itemIndex = categories[catIndex].items.firstIndex(where: { $0.id == itemId }) else {
            return false
        }

        categories[catIndex].items[itemIndex].text = trimmed
        categories[catIndex].items[itemIndex].timestamp = Date()
        save()
        return true
    }

    func deleteItem(from categoryId: UUID, itemId: UUID) -> Bool {
        guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }) else {
            return false
        }
        // Allow deletion from default category too
        categories[catIndex].items.removeAll { $0.id == itemId }
        save()
        return true
    }

    func moveItem(itemId: UUID, from sourceCategoryId: UUID, to targetCategoryId: UUID) -> Bool {
        guard let sourceIndex = categories.firstIndex(where: { $0.id == sourceCategoryId }),
              let targetIndex = categories.firstIndex(where: { $0.id == targetCategoryId }),
              let itemIndex = categories[sourceIndex].items.firstIndex(where: { $0.id == itemId }) else {
            return false
        }

        var item = categories[sourceIndex].items.remove(at: itemIndex)
        item.timestamp = Date()
        categories[targetIndex].items.insert(item, at: 0)
        save()
        return true
    }

    func updateItemOrder(in categoryId: UUID, itemIds: [UUID]) {
        guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }) else { return }
        var reordered: [HistoryItem] = []
        let existingItems = categories[catIndex].items
        for id in itemIds {
            if let item = existingItems.first(where: { $0.id == id }) {
                reordered.append(item)
            }
        }
        // Append any items not in the list (shouldn't happen, but safety)
        for item in existingItems where !reordered.contains(where: { $0.id == item.id }) {
            reordered.append(item)
        }
        categories[catIndex].items = reordered
        save()
    }

    // MARK: - Default Category Operations

    /// Add an item to the default clipboard history category (used by ClipboardMonitor)
    func addToDefaultHistory(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let catIndex = categories.firstIndex(where: { $0.isDefault }) else { return }

        // Remove duplicate
        categories[catIndex].items.removeAll { $0.text == trimmed }

        let newItem = HistoryItem(id: UUID(), text: trimmed, timestamp: Date())
        categories[catIndex].items.insert(newItem, at: 0)

        // Enforce max count
        if categories[catIndex].items.count > kMaxHistoryCount {
            categories[catIndex].items = Array(categories[catIndex].items.prefix(kMaxHistoryCount))
        }

        save()
    }

    /// Clear all items in the default category
    func clearDefaultHistory() {
        guard let catIndex = categories.firstIndex(where: { $0.isDefault }) else { return }
        categories[catIndex].items.removeAll()
        save()
    }

    /// Get items from the default category (for backward-compatible access)
    func defaultHistoryItems(limit: Int = 30) -> [HistoryItem] {
        guard let catIndex = categories.firstIndex(where: { $0.isDefault }) else { return [] }
        return Array(categories[catIndex].items.prefix(limit))
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(categories)
            try data.write(to: URL(fileURLWithPath: kCategoriesFilePath), options: .atomic)
        } catch {
            NSLog("Clipboard: Failed to save categories: \(error)")
        }
    }

    private func load() {
        let url = URL(fileURLWithPath: kCategoriesFilePath)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            categories = []
            return
        }
        do {
            categories = try JSONDecoder().decode([Category].self, from: data)
        } catch {
            NSLog("Clipboard: Failed to load categories: \(error)")
            categories = []
        }
    }
}
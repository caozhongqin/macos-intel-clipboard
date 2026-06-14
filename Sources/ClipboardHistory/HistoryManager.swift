import Foundation
import AppKit

/// HistoryManager is now a thin wrapper around CategoryManager for backward compatibility.
/// All data is stored in CategoryManager.
class HistoryManager {
    static let shared = HistoryManager()

    private(set) var items: [HistoryItem] = []

    private init() {}

    // MARK: - Public API

    /// Add a new item to default history
    func add(text: String) {
        CategoryManager.shared.addToDefaultHistory(text: text)
    }

    /// Remove a specific item by id from the default category
    func remove(id: UUID) {
        guard let defaultCat = CategoryManager.shared.defaultCategory else { return }
        _ = CategoryManager.shared.deleteItem(from: defaultCat.id, itemId: id)
    }

    /// Clear all default history
    func clear() {
        CategoryManager.shared.clearDefaultHistory()
    }

    /// Get recent items from default category
    func recentItems(limit: Int = 30) -> [HistoryItem] {
        CategoryManager.shared.defaultHistoryItems(limit: limit)
    }
}
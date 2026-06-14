import Foundation
import AppKit

class HistoryManager {
    static let shared = HistoryManager()

    private(set) var items: [HistoryItem] = []

    private init() {
        load()
    }

    // MARK: - Public API

    /// Add a new item to history. If an item with the same text exists,
    /// it is removed first (so the new one becomes the most recent).
    func add(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Remove duplicate
        items.removeAll { $0.text == trimmed }

        let newItem = HistoryItem(id: UUID(), text: trimmed, timestamp: Date())
        items.insert(newItem, at: 0)

        // Enforce max count
        if items.count > kMaxHistoryCount {
            items = Array(items.prefix(kMaxHistoryCount))
        }

        save()
    }

    /// Remove a specific item by id
    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    /// Clear all history
    func clear() {
        items.removeAll()
        save()
    }

    /// Get recent items (up to `limit`)
    func recentItems(limit: Int = 30) -> [HistoryItem] {
        Array(items.prefix(limit))
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: URL(fileURLWithPath: kHistoryFilePath), options: .atomic)
        } catch {
            NSLog("Clipboard: Failed to save history: \(error)")
        }
    }

    private func load() {
        let url = URL(fileURLWithPath: kHistoryFilePath)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return
        }
        do {
            items = try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            NSLog("Clipboard: Failed to load history: \(error)")
            items = []
        }
    }
}
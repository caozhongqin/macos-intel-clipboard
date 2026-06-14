import Foundation

struct HistoryItem: Codable, Equatable {
    let id: UUID
    var text: String
    var timestamp: Date

    static func == (lhs: HistoryItem, rhs: HistoryItem) -> Bool {
        lhs.text == rhs.text
    }
}

struct Category: Codable, Equatable {
    let id: UUID
    var name: String
    var isDefault: Bool
    var sortOrder: Int
    var items: [HistoryItem]

    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
}

/// Maximum number of history items in the default category
let kMaxHistoryCount = 50

/// Categories file path
let kCategoriesFilePath: String = {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent(".clipboard-categories.json").path
}()
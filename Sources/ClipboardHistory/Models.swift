import Foundation

struct HistoryItem: Codable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date

    static func == (lhs: HistoryItem, rhs: HistoryItem) -> Bool {
        lhs.text == rhs.text
    }
}

/// Maximum number of history items to store
let kMaxHistoryCount = 200

/// History file path
let kHistoryFilePath: String = {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent(".clipboard-history.json").path
}()
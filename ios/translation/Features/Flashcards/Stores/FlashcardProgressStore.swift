import Foundation
import SwiftUI

// 二元熟悉度儲存：以 Set 紀錄熟悉的卡片鍵（未在集合中者即為不熟悉）
@MainActor
final class FlashcardProgressStore: ObservableObject {
    // 使用新 key，與舊等級制資料分離
    private let key = "flashcard.familiar.keys"
    // key format: "<deckID>:<cardID>"
    @Published private var familiarKeys: Set<String> = [] { didSet { persist() } }

    init() { load() }

    private func k(_ deckID: UUID, _ cardID: UUID) -> String { "\(deckID.uuidString):\(cardID.uuidString)" }

    // 查詢是否為熟悉
    func isFamiliar(deckID: UUID, cardID: UUID) -> Bool {
        familiarKeys.contains(k(deckID, cardID))
    }

    // 設為熟悉 / 不熟悉
    func markFamiliar(deckID: UUID, cardID: UUID) {
        familiarKeys.insert(k(deckID, cardID))
    }
    func markUnfamiliar(deckID: UUID, cardID: UUID) {
        familiarKeys.remove(k(deckID, cardID))
    }
    func toggle(deckID: UUID, cardID: UUID) {
        let key = k(deckID, cardID)
        if familiarKeys.contains(key) { familiarKeys.remove(key) } else { familiarKeys.insert(key) }
    }

    // 與舊 API 相容（暫不使用）：以 1/0 回傳
    func level(deckID: UUID, cardID: UUID) -> Int { isFamiliar(deckID: deckID, cardID: cardID) ? 1 : 0 }

    // MARK: - Persistence
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            AppLog.flashcardsDebug("No existing flashcard progress data found in UserDefaults")
            return
        }
        do {
            let arr = try JSONDecoder().decode([String].self, from: data)
            familiarKeys = Set(arr)
            AppLog.flashcardsDebug("Successfully loaded \(familiarKeys.count) flashcard progress items from UserDefaults")
        } catch {
            AppLog.flashcardsError("Failed to decode flashcard progress from UserDefaults: \(error.localizedDescription)")
            familiarKeys = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(Array(familiarKeys))
            UserDefaults.standard.set(data, forKey: key)
            AppLog.flashcardsDebug("Successfully persisted \(familiarKeys.count) flashcard progress items to UserDefaults")
        } catch {
            AppLog.flashcardsError("Failed to persist flashcard progress to UserDefaults: \(error.localizedDescription)")
        }
    }

    // 全部重置為「不熟悉」
    func clearAll() {
        familiarKeys.removeAll()
    }

    // 將特定 deck 內的卡片全部設為「不熟悉」
    func clearDeck(deckID: UUID) {
        let prefix = deckID.uuidString + ":"
        familiarKeys = familiarKeys.filter { !$0.hasPrefix(prefix) }
    }
}

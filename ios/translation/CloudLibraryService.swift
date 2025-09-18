import Foundation
import SwiftUI

// Cloud curated content (read-only): decks and bank books
// Provides HTTP-backed implementation when BACKEND_URL is set, and a mock otherwise.

struct CloudDeckSummary: Codable, Identifiable, Equatable { let id: String; let name: String; let count: Int }
struct CloudDeckDetail: Codable, Equatable { let id: String; let name: String; let cards: [Flashcard] }

struct CloudBookSummary: Codable, Identifiable, Equatable { var id: String { name }; let name: String; let count: Int }
struct CloudBookDetail: Codable, Equatable { let name: String; let items: [BankItem] }

protocol CloudLibraryService {
    func fetchDecks() async throws -> [CloudDeckSummary]
    func fetchDeckDetail(id: String) async throws -> CloudDeckDetail
    func fetchBooks() async throws -> [CloudBookSummary]
    func fetchBook(name: String) async throws -> CloudBookDetail
}

enum CloudLibraryServiceFactory {
    static func makeDefault() -> CloudLibraryService {
        if AppConfig.backendURL != nil { return CloudLibraryHTTP() }
        return CloudLibraryMock()
    }
}

final class CloudLibraryHTTP: CloudLibraryService {
    private var base: URL { AppConfig.backendURL! }

    func fetchDecks() async throws -> [CloudDeckSummary] {
        let url = base.appendingPathComponent("cloud").appendingPathComponent("decks")
        AppLog.uiInfo("[cloud] GET /cloud/decks")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([CloudDeckSummary].self, from: data)
    }

    func fetchDeckDetail(id: String) async throws -> CloudDeckDetail {
        let url = base.appendingPathComponent("cloud").appendingPathComponent("decks").appendingPathComponent(id)
        AppLog.uiInfo("[cloud] GET /cloud/decks/\(id)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        // Expecting cards as DTO compatible with app Flashcard; map if needed.
        return try JSONDecoder().decode(CloudDeckDetail.self, from: data)
    }

    func fetchBooks() async throws -> [CloudBookSummary] {
        let url = base.appendingPathComponent("cloud").appendingPathComponent("books")
        AppLog.uiInfo("[cloud] GET /cloud/books")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([CloudBookSummary].self, from: data)
    }

    func fetchBook(name: String) async throws -> CloudBookDetail {
        // Append path components directly so the system handles encoding once
        let url = base.appendingPathComponent("cloud").appendingPathComponent("books").appendingPathComponent(name)
        AppLog.uiInfo("[cloud] GET /cloud/books/<name>")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(CloudBookDetail.self, from: data)
    }
}

final class CloudLibraryMock: CloudLibraryService {
    func fetchDecks() async throws -> [CloudDeckSummary] {
        return [
            CloudDeckSummary(id: "starter-phrases", name: "Starter Phrases", count: 12),
            CloudDeckSummary(id: "common-errors", name: "Common Errors", count: 18)
        ]
    }

    func fetchDeckDetail(id: String) async throws -> CloudDeckDetail {
        switch id {
        case "starter-phrases":
            let cards: [Flashcard] = [
                Flashcard(front: "Hello!", back: "你好！"),
                Flashcard(front: "How are you?", back: "你最近好嗎？")
            ]
            return CloudDeckDetail(id: id, name: "Starter Phrases", cards: cards)
        case "common-errors":
            let cards: [Flashcard] = [
                Flashcard(front: "I look forward to hear from you.", back: "更自然：I look forward to hearing from you."),
                Flashcard(front: "He suggested me to go.", back: "更自然：He suggested that I go / He suggested going.")
            ]
            return CloudDeckDetail(id: id, name: "Common Errors", cards: cards)
        default:
            return CloudDeckDetail(id: id, name: id, cards: [])
        }
    }

    func fetchBooks() async throws -> [CloudBookSummary] {
        return [
            CloudBookSummary(name: "Daily Conversations", count: 20),
            CloudBookSummary(name: "Academic Writing", count: 15)
        ]
    }

    func fetchBook(name: String) async throws -> CloudBookDetail {
        switch name {
        case "Daily Conversations":
            let items: [BankItem] = [
                BankItem(id: "conv-greet", zh: "跟陌生人打招呼", hints: [], suggestions: [], tags: ["daily"], difficulty: 1, completed: nil),
                BankItem(id: "conv-order", zh: "點餐時的常見句型", hints: [], suggestions: [], tags: ["daily"], difficulty: 2, completed: nil)
            ]
            return CloudBookDetail(name: name, items: items)
        case "Academic Writing":
            let items: [BankItem] = [
                BankItem(id: "acad-intro", zh: "撰寫研究引言", hints: [], suggestions: [], tags: ["academic"], difficulty: 3, completed: nil),
                BankItem(id: "acad-method", zh: "描述研究方法", hints: [], suggestions: [], tags: ["academic"], difficulty: 3, completed: nil)
            ]
            return CloudBookDetail(name: name, items: items)
        default:
            return CloudBookDetail(name: name, items: [])
        }
    }
}

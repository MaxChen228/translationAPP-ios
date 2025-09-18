import Foundation
import SwiftUI

// Cloud curated content (read-only): decks and bank books
// Requires BACKEND_URL; no mock fallback.

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
    static func makeDefault() -> CloudLibraryService { CloudLibraryHTTP() }
}

final class CloudLibraryHTTP: CloudLibraryService {
    private var base: URL {
        guard let u = AppConfig.backendURL else {
            // Methods should only be called after UI has guarded env
            fatalError("BACKEND_URL missing")
        }
        return u
    }

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

// Mock implementation removed: BACKEND_URL is required for cloud operations.

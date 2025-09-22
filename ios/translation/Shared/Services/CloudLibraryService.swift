import Foundation
import SwiftUI

// Cloud curated content (read-only): decks and bank courses/books
// Requires BACKEND_URL; no mock fallback.

struct CloudDeckSummary: Codable, Identifiable, Equatable { let id: String; let name: String; let count: Int }
struct CloudDeckDetail: Codable, Equatable { let id: String; let name: String; let cards: [Flashcard] }

struct CloudCourseSummary: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String?
    let coverImage: String?
    let tags: [String]
    let bookCount: Int
}

struct CloudCourseBook: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String?
    let coverImage: String?
    let tags: [String]
    let difficulty: Int?
    let itemCount: Int
    let items: [BankItem]
}

struct CloudCourseDetail: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String?
    let coverImage: String?
    let tags: [String]
    let bookCount: Int
    let books: [CloudCourseBook]
}

struct CloudSearchBookHit: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String?
    let coverImage: String?
    let tags: [String]
    let difficulty: Int?
    let itemCount: Int
    let courseId: String
}

struct CloudSearchResponse: Codable, Equatable {
    let query: String
    let courses: [CloudCourseSummary]
    let books: [CloudSearchBookHit]
}

protocol CloudLibraryService {
    func fetchDecks() async throws -> [CloudDeckSummary]
    func fetchDeckDetail(id: String) async throws -> CloudDeckDetail
    func fetchCourses() async throws -> [CloudCourseSummary]
    func fetchCourseDetail(id: String) async throws -> CloudCourseDetail
    func fetchCourseBook(courseId: String, bookId: String) async throws -> CloudCourseBook
    func search(query: String) async throws -> CloudSearchResponse
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

    func fetchCourses() async throws -> [CloudCourseSummary] {
        let url = base.appendingPathComponent("cloud").appendingPathComponent("courses")
        AppLog.uiInfo("[cloud] GET /cloud/courses")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([CloudCourseSummary].self, from: data)
    }

    func fetchCourseDetail(id: String) async throws -> CloudCourseDetail {
        let url = base.appendingPathComponent("cloud").appendingPathComponent("courses").appendingPathComponent(id)
        AppLog.uiInfo("[cloud] GET /cloud/courses/\(id)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(CloudCourseDetail.self, from: data)
    }

    func fetchCourseBook(courseId: String, bookId: String) async throws -> CloudCourseBook {
        let url = base
            .appendingPathComponent("cloud")
            .appendingPathComponent("courses")
            .appendingPathComponent(courseId)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId)
        AppLog.uiInfo("[cloud] GET /cloud/courses/\(courseId)/books/\(bookId)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(CloudCourseBook.self, from: data)
    }

    func search(query: String) async throws -> CloudSearchResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CloudSearchResponse(query: "", courses: [], books: [])
        }
        var components = URLComponents(url: base.appendingPathComponent("cloud").appendingPathComponent("search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        guard let url = components?.url else { throw URLError(.badURL) }
        AppLog.uiInfo("[cloud] GET /cloud/search?q=…")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(CloudSearchResponse.self, from: data)
    }
}

// Mock implementation removed: BACKEND_URL is required for cloud operations.

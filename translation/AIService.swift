import Foundation
import SwiftUI
import OSLog

// MARK: - Service Result

struct AICorrectionResult {
    var response: AIResponse
    // Optional precomputed highlights. If nil, caller can compute via Highlighter.
    var originalHighlights: [Highlight]? = nil
    var correctedHighlights: [Highlight]? = nil
}

// MARK: - Protocol

protocol AIService {
    func correct(zh: String, en: String) async throws -> AICorrectionResult
}

// MARK: - Factory

enum AIServiceFactory {
    static func makeDefault() -> AIService {
        if let url = AppConfig.correctAPIURL {
            AppLog.aiInfo("Using HTTP AIService: \(url.absoluteString)")
            return AIServiceHTTP(endpoint: url)
        }
        AppLog.aiInfo("Using MockAIService")
        return MockAIService()
    }
}

// MARK: - App Config

enum AppConfig {
    // Preferred: Info.plist key "TRANSLATION_CORRECT_URL" (full URL)
    // Fallback: environment variable "TRANSLATION_CORRECT_URL"
    static var correctAPIURL: URL? {
        if let s = Bundle.main.object(forInfoDictionaryKey: "TRANSLATION_CORRECT_URL") as? String,
           let u = URL(string: s), !s.isEmpty { return u }
        if let s = ProcessInfo.processInfo.environment["TRANSLATION_CORRECT_URL"],
           let u = URL(string: s), !s.isEmpty { return u }
        return nil
    }

    static var bankBaseURL: URL? {
        if let s = Bundle.main.object(forInfoDictionaryKey: "BANK_BASE_URL") as? String,
           let u = URL(string: s), !s.isEmpty { return u }
        if let s = ProcessInfo.processInfo.environment["BANK_BASE_URL"],
           let u = URL(string: s), !s.isEmpty { return u }
        return nil
    }
}

// MARK: - Mock Implementation

final class MockAIService: AIService {
    func correct(zh: String, en: String) async throws -> AICorrectionResult {
        // Use deterministic mock similar to existing runMockCorrection()
        let errors: [ErrorItem] = [
            ErrorItem(
                id: UUID(),
                span: "go",
                type: .morphological,
                explainZh: "應使用過去式。",
                suggestion: "went",
                hints: ErrorHints(before: "I ", after: " to", occurrence: 1)
            ),
            ErrorItem(
                id: UUID(),
                span: "shop",
                type: .lexical,
                explainZh: "在此情境更常用 store。",
                suggestion: "store",
                hints: ErrorHints(before: "the ", after: " yesterday", occurrence: nil)
            ),
            ErrorItem(
                id: UUID(),
                span: "fruits",
                type: .pragmatic,
                explainZh: "可數名詞泛指時常用單數不可數。",
                suggestion: "fruit",
                hints: ErrorHints(before: "some ", after: ".", occurrence: nil)
            )
        ]

        let corrected = "I went to the store yesterday to buy some fruit."
        let response = AIResponse(corrected: corrected, score: 85, errors: errors)

        // Prefer computing highlights here to isolate logic
        let originalHighlights = Highlighter.computeHighlights(text: en, errors: errors)
        let correctedHighlights = Highlighter.computeHighlightsInCorrected(text: corrected, errors: errors)

        return AICorrectionResult(response: response, originalHighlights: originalHighlights, correctedHighlights: correctedHighlights)
    }
}

// MARK: - HTTP Implementation

final class AIServiceHTTP: AIService {
    private let endpoint: URL
    private let session: URLSession

    init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    struct RequestBody: Codable {
        let zh: String
        let en: String
        let bankItemId: String?
        let deviceId: String?
    }

    // DTOs allow indices while mapping back to app models
    struct RangeDTO: Codable { let start: Int; let length: Int }
    struct ErrorHintsDTO: Codable { let before: String?; let after: String?; let occurrence: Int? }
    struct ErrorDTO: Codable {
        let id: UUID?
        let span: String
        let type: String
        let explainZh: String
        let suggestion: String?
        let hints: ErrorHintsDTO?
        let originalRange: RangeDTO?
        let suggestionRange: RangeDTO?
        let correctedRange: RangeDTO?
    }
    struct ResponseDTO: Codable {
        let corrected: String
        let score: Int
        let errors: [ErrorDTO]
    }

    // Backward-compatible entry (protocol requirement)
    func correct(zh: String, en: String) async throws -> AICorrectionResult {
        try await correct(zh: zh, en: en, bankItemId: nil, deviceId: DeviceID.current)
    }

    // Preferred entry with metadata for progress tracking
    func correct(zh: String, en: String, bankItemId: String?, deviceId: String? = DeviceID.current) async throws -> AICorrectionResult {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(RequestBody(zh: zh, en: en, bankItemId: bankItemId, deviceId: deviceId))

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw URLError(.badServerResponse, userInfo: ["status": code])
        }

        let dto = try JSONDecoder().decode(ResponseDTO.self, from: data)

        // Map DTO -> app models
        var errors: [ErrorItem] = []
        errors.reserveCapacity(dto.errors.count)
        for e in dto.errors {
            let type = ErrorType(rawValue: e.type) ?? .lexical
            let hints: ErrorHints? = {
                guard let h = e.hints else { return nil }
                return ErrorHints(before: h.before, after: h.after, occurrence: h.occurrence)
            }()
            errors.append(ErrorItem(id: e.id ?? UUID(), span: e.span, type: type, explainZh: e.explainZh, suggestion: e.suggestion, hints: hints))
        }

        let response = AIResponse(corrected: dto.corrected, score: dto.score, errors: errors)

        // Compute highlights, prefer indices if provided
        let originalHighlights = computeOriginalHighlights(en: en, dtoErrors: dto.errors)
        let correctedHighlights = computeCorrectedHighlights(corrected: dto.corrected, dtoErrors: dto.errors)

        // If no indices provided, fall back to Highlighter
        let finalOriginal = originalHighlights.isEmpty ? Highlighter.computeHighlights(text: en, errors: errors) : originalHighlights
        let finalCorrected = correctedHighlights.isEmpty ? Highlighter.computeHighlightsInCorrected(text: dto.corrected, errors: errors) : correctedHighlights

        return AICorrectionResult(response: response, originalHighlights: finalOriginal, correctedHighlights: finalCorrected)
    }

    private func computeOriginalHighlights(en: String, dtoErrors: [ErrorDTO]) -> [Highlight] {
        var result: [Highlight] = []
        for e in dtoErrors {
            guard let r = e.originalRange,
                  let range = Self.utf16RangeToStringRange(in: en, start: r.start, length: r.length) else { continue }
            let type = ErrorType(rawValue: e.type) ?? .lexical
            let id = e.id ?? UUID()
            result.append(Highlight(id: id, range: range, type: type))
        }
        return result
    }

    private func computeCorrectedHighlights(corrected: String, dtoErrors: [ErrorDTO]) -> [Highlight] {
        var result: [Highlight] = []
        for e in dtoErrors {
            // Prefer explicit corrected/suggestion range if provided
            let correctedRange = e.correctedRange ?? e.suggestionRange
            guard let r = correctedRange,
                  let range = Self.utf16RangeToStringRange(in: corrected, start: r.start, length: r.length) else { continue }
            let type = ErrorType(rawValue: e.type) ?? .lexical
            let id = e.id ?? UUID()
            result.append(Highlight(id: id, range: range, type: type))
        }
        return result
    }

    // Convert UTF-16 offset/length to Swift String.Index range
    private static func utf16RangeToStringRange(in s: String, start: Int, length: Int) -> Range<String.Index>? {
        guard start >= 0, length >= 0 else { return nil }
        let utf16 = s.utf16
        guard let from = utf16.index(utf16.startIndex, offsetBy: start, limitedBy: utf16.endIndex),
              let to = utf16.index(from, offsetBy: length, limitedBy: utf16.endIndex),
              let lower = String.Index(from, within: s),
              let upper = String.Index(to, within: s),
              lower <= upper else { return nil }
        return lower..<upper
    }
}

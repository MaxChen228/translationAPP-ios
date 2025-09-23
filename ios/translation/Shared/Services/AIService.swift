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
        AppLog.aiError("BACKEND_URL missing: AIService unavailable")
        return UnavailableAIService()
    }
}

// MARK: - App Config

enum AppConfig {
    // Single source of truth: BACKEND_URL
    static var backendURL: URL? {
        // Prefer runtime environment for easy override when running on device via Xcode.
        if let s = ProcessInfo.processInfo.environment["BACKEND_URL"],
           let u = URL(string: s), !s.isEmpty { return u }

        // Hardcoded fallback for production (Xcode 16 doesn't support custom INFOPLIST_KEY_*)
        return URL(string: "https://translation-l9qi.onrender.com")
    }

    // All service endpoints derive from BACKEND_URL
    static var correctAPIURL: URL? {
        guard let base = backendURL else { return nil }
        return base.appendingPathComponent("correct")
    }

    static var chatRespondURL: URL? {
        guard let base = backendURL else { return nil }
        return base.appendingPathComponent("chat/respond")
    }

    static var chatResearchURL: URL? {
        guard let base = backendURL else { return nil }
        return base.appendingPathComponent("chat/research")
    }
}

// MARK: - Unavailable stub (when BACKEND_URL missing)

final class UnavailableAIService: AIService {
    struct MissingBackendError: LocalizedError {
        var errorDescription: String? { String(localized: "error.backend.missing") }
    }
    func correct(zh: String, en: String) async throws -> AICorrectionResult {
        throw MissingBackendError()
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
        // 新增：題庫提示（陣列，由後端自行解碼）與教師建議（非結構化段落）
        let hints: [HintDTO]?
        let suggestion: String?
        // 選用：指定 LLM 模型（例如 gemini-2.5-pro / gemini-2.5-flash）
        let model: String?
    }

    struct HintDTO: Codable {
        let category: String
        let text: String
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
        try await correct(zh: zh, en: en, bankItemId: nil, deviceId: DeviceID.current, hints: nil, suggestion: nil)
    }

    // Preferred entry with metadata for progress tracking
    func correct(zh: String, en: String, bankItemId: String?, deviceId: String? = DeviceID.current, hints: [BankHint]? = nil, suggestion: String? = nil) async throws -> AICorrectionResult {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let hintDTOs: [HintDTO]? = hints?.map { h in
            HintDTO(category: h.category.rawValue, text: h.text)
        }
        // 從設定讀取糾錯專用的 gemini model
        let model = UserDefaults.standard.string(forKey: "settings.correctionModel")
        req.httpBody = try JSONEncoder().encode(RequestBody(zh: zh, en: en, bankItemId: bankItemId, deviceId: deviceId, hints: hintDTOs, suggestion: suggestion, model: model))

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

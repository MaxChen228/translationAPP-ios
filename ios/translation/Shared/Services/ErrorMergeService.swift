import Foundation

protocol ErrorMerging {
    func merge(zh: String, en: String, corrected: String, errors: [ErrorItem], rationale: String?) async throws -> ErrorItem
}

struct ErrorMergeServiceHTTP: ErrorMerging {
    private let endpoint: URL
    private let session: URLSession

    init?(endpoint: URL?, session: URLSession = .shared) {
        guard let endpoint else { return nil }
        self.endpoint = endpoint
        self.session = session
    }

    func merge(zh: String, en: String, corrected: String, errors: [ErrorItem], rationale: String?) async throws -> ErrorItem {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DeviceID.current, forHTTPHeaderField: "X-Device-Id")

        let dtoErrors = errors.map(ErrorDTO.init)
        let model = UserDefaults.standard.string(forKey: "settings.correctionModel")
        let body = RequestBody(
            zh: zh,
            en: en,
            corrected: corrected,
            errors: dtoErrors,
            rationale: rationale,
            deviceId: DeviceID.current,
            model: model
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw URLError(.badServerResponse, userInfo: ["status": status])
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(ResponseBody.self, from: data)
        return payload.error.asModel()
    }
}

enum ErrorMergeServiceFactory {
    static func makeDefault() -> ErrorMerging {
        if let service = ErrorMergeServiceHTTP(endpoint: AppConfig.backendURL?.appendingPathComponent("correct/merge")) {
            return service
        }
        return UnavailableErrorMergeService()
    }
}

private struct RequestBody: Codable {
    let zh: String
    let en: String
    let corrected: String
    let errors: [ErrorDTO]
    let rationale: String?
    let deviceId: String?
    let model: String?
}

private struct ResponseBody: Codable {
    let error: ErrorDTO
}

private struct ErrorDTO: Codable {
    struct HintsDTO: Codable {
        let before: String?
        let after: String?
        let occurrence: Int?
    }

    let id: UUID?
    let span: String
    let type: String
    let explainZh: String
    let suggestion: String?
    let hints: HintsDTO?

    init(_ item: ErrorItem) {
        id = item.id
        span = item.span
        type = item.type.rawValue
        explainZh = item.explainZh
        suggestion = item.suggestion
        if let hints = item.hints {
            self.hints = HintsDTO(before: hints.before, after: hints.after, occurrence: hints.occurrence)
        } else {
            self.hints = nil
        }
    }

    func asModel() -> ErrorItem {
        let errorType = ErrorType(rawValue: type) ?? .lexical
        let hint: ErrorHints? = hints.map { ErrorHints(before: $0.before, after: $0.after, occurrence: $0.occurrence) }
        return ErrorItem(id: id ?? UUID(), span: span, type: errorType, explainZh: explainZh, suggestion: suggestion, hints: hint)
    }
}

private struct UnavailableErrorMergeService: ErrorMerging {
    struct MergeUnavailableError: LocalizedError {
        var errorDescription: String? { String(localized: "error.merge.backendMissing") }
    }

    func merge(zh: String, en: String, corrected: String, errors: [ErrorItem], rationale: String?) async throws -> ErrorItem {
        throw MergeUnavailableError()
    }
}

import Foundation

struct CorrectionServiceResult: Equatable {
    var response: AIResponse
    var originalHighlights: [Highlight]
    var correctedHighlights: [Highlight]
}

protocol CorrectionServiceAdapter {
    func correct(
        zh: String,
        en: String,
        currentBankItemId: String?,
        hints: [BankHint],
        suggestion: String?
    ) async throws -> CorrectionServiceResult
}

final class DefaultCorrectionServiceAdapter: CorrectionServiceAdapter {
    private let service: AIService

    init(service: AIService) {
        self.service = service
    }

    func correct(
        zh: String,
        en: String,
        currentBankItemId: String?,
        hints: [BankHint],
        suggestion: String?
    ) async throws -> CorrectionServiceResult {
        let result: AICorrectionResult
        if let http = service as? AIServiceHTTP {
            result = try await http.correct(
                zh: zh,
                en: en,
                bankItemId: currentBankItemId,
                deviceId: DeviceID.current,
                hints: hints,
                suggestion: suggestion
            )
        } else {
            result = try await service.correct(zh: zh, en: en)
        }

        let response = result.response
        let originalHighlights = result.originalHighlights
            ?? Highlighter.computeHighlights(text: en, errors: response.errors)
        let correctedHighlights = result.correctedHighlights
            ?? Highlighter.computeHighlightsInCorrected(text: response.corrected, errors: response.errors)

        AppLog.aiInfo("Correction success: score=\(response.score), errors=\(response.errors.count)")

        return CorrectionServiceResult(
            response: response,
            originalHighlights: originalHighlights,
            correctedHighlights: correctedHighlights
        )
    }
}

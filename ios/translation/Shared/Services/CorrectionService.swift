import Foundation

protocol CorrectionRunning {
    func runCorrection(
        zh: String,
        en: String,
        bankItemId: String?,
        deviceId: String?,
        hints: [BankHint]?,
        suggestion: String?
    ) async throws -> AICorrectionResult
}

struct CorrectionService: CorrectionRunning {
    private let aiService: AIService

    init(aiService: AIService) {
        self.aiService = aiService
    }

    func runCorrection(
        zh: String,
        en: String,
        bankItemId: String?,
        deviceId: String?,
        hints: [BankHint]?,
        suggestion: String?
    ) async throws -> AICorrectionResult {
        if let http = aiService as? AIServiceHTTP {
            return try await http.correct(
                zh: zh,
                en: en,
                bankItemId: bankItemId,
                deviceId: deviceId,
                hints: hints,
                suggestion: suggestion
            )
        }
        return try await aiService.correct(zh: zh, en: en)
    }
}

enum CorrectionServiceFactory {
    static func makeDefault() -> CorrectionRunning {
        CorrectionService(aiService: AIServiceFactory.makeDefault())
    }
}

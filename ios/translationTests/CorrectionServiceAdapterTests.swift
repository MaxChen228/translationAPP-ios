import Foundation
import Testing
@testable import translation

@MainActor
struct CorrectionServiceAdapterTests {
    @Test("Adapter computes highlights when backend omits them")
    func testComputesHighlightsWhenMissing() async throws {
        let error = ErrorItem(
            id: UUID(),
            span: "error",
            type: .lexical,
            explainZh: "錯誤",
            suggestion: "fix",
            hints: nil
        )
        let response = AIResponse(corrected: "This is error", score: 90, errors: [error])
        let service = MockAIService(result: AICorrectionResult(response: response, originalHighlights: nil, correctedHighlights: nil))
        let adapter = DefaultCorrectionServiceAdapter(service: service)

        let result = try await adapter.correct(
            zh: "中文",
            en: "This is error",
            currentBankItemId: nil,
            hints: [],
            suggestion: nil
        )

        #expect(result.response == response)
        #expect(result.originalHighlights.count == 1)
        #expect(result.correctedHighlights.count == 1)
        #expect(service.receivedParameters?.zh == "中文")
    }
}

private final class MockAIService: AIService {
    var result: AICorrectionResult
    var receivedParameters: (zh: String, en: String)? = nil

    init(result: AICorrectionResult) {
        self.result = result
    }

    func correct(zh: String, en: String) async throws -> AICorrectionResult {
        receivedParameters = (zh, en)
        return result
    }
}

import Foundation
import SwiftUI
import OSLog

@MainActor
final class CorrectionViewModel: ObservableObject {
    // Per-workspace keys; prefix 由 workspaceID 組成
    private let workspacePrefix: String
    private var keyInputZh: String { workspacePrefix + "inputZh" }
    private var keyInputEn: String { workspacePrefix + "inputEn" }
    private var keyResponse: String { workspacePrefix + "response" }
    private var keyHints: String { workspacePrefix + "practicedHints" }
    private var keyShowHints: String { workspacePrefix + "showPracticedHints" }

    @Published var inputZh: String = "" { didSet { if inputZh != oldValue { UserDefaults.standard.set(inputZh, forKey: keyInputZh) } } }
    @Published var inputEn: String = "" { didSet { if inputEn != oldValue { UserDefaults.standard.set(inputEn, forKey: keyInputEn) } } }

    @Published var response: AIResponse? { didSet { persistResponse() } }
    @Published var highlights: [Highlight] = []
    @Published var correctedHighlights: [Highlight] = []
    @Published var selectedErrorID: UUID?
    @Published var filterType: ErrorType? = nil
    @Published var popoverError: ErrorItem? = nil
    @Published var cardMode: ResultSwitcherCard.Mode = .original

    // Networking
    private let service: AIService
    private let workspaceID: String
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Practice hints (from bank) to render under Chinese input
    @Published var practicedHints: [BankHint] = [] { didSet { persistHints() } }
    @Published var showPracticedHints: Bool = false { didSet { UserDefaults.standard.set(showPracticedHints, forKey: keyShowHints) } }
    // Signal to request focusing EN text field in ContentView
    @Published var focusEnSignal: Int = 0

    // 題庫整合：紀錄目前要練習的題目 ID（若從題庫進入）
    @Published var currentBankItemId: String? = nil
    @Published var currentPracticeTag: String? = nil


    init(service: AIService = AIServiceFactory.makeDefault(), workspaceID: String = "default") {
        self.service = service
        self.workspaceID = workspaceID
        self.workspacePrefix = "workspace.\(workspaceID)."
        // 載入持久化狀態
        self.inputZh = UserDefaults.standard.string(forKey: keyInputZh) ?? ""
        self.inputEn = UserDefaults.standard.string(forKey: keyInputEn) ?? ""
        if let data = UserDefaults.standard.data(forKey: keyResponse) {
            self.response = try? JSONDecoder().decode(AIResponse.self, from: data)
        }
        if let data = UserDefaults.standard.data(forKey: keyHints),
           let hints = try? JSONDecoder().decode([BankHint].self, from: data) {
            self.practicedHints = hints
        }
        self.showPracticedHints = UserDefaults.standard.bool(forKey: keyShowHints)
        AppLog.aiInfo("CorrectionViewModel initialized (ws=\(workspaceID)) with service: \(String(describing: type(of: service)))")
    }

    func reset() {
        inputZh = ""
        inputEn = ""
        response = nil
        highlights = []
        correctedHighlights = []
        selectedErrorID = nil
        filterType = nil
        popoverError = nil
        cardMode = .original
        practicedHints = []
        showPracticedHints = false
        // 同步清掉持久化，符合「除非按右下角刪除才清空」
        let ud = UserDefaults.standard
        ud.removeObject(forKey: keyInputZh)
        ud.removeObject(forKey: keyInputEn)
        ud.removeObject(forKey: keyResponse)
        ud.removeObject(forKey: keyHints)
        ud.removeObject(forKey: keyShowHints)
    }

    func fillExample() {
        inputZh = "我昨天去商店買水果。"
        inputEn = "I go to the shop yesterday to buy some fruits."
    }

    func requestFocusEn() {
        focusEnSignal &+= 1
    }

    // 移除舊的 Sheet 題庫流程；改為列表頁直接回填中文

    // 真實批改（若無後端設定則使用 MockAIService）
    func runCorrection() async {
        let user = inputEn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty else {
            let err = ErrorItem(
                id: UUID(),
                span: "",
                type: .pragmatic,
                explainZh: "請先輸入你的英文嘗試再批改。",
                suggestion: nil,
                hints: nil
            )
            let res = AIResponse(corrected: "", score: 0, errors: [err])
            self.response = res
            self.highlights = []
            self.correctedHighlights = []
            self.selectedErrorID = nil
            return
        }

        if inputZh.isEmpty { inputZh = "我昨天去商店買水果。" }

        isLoading = true
        errorMessage = nil
        do {
            AppLog.aiInfo("Start correction via \(String(describing: type(of: self.service)))")
            let result: AICorrectionResult
            if let http = self.service as? AIServiceHTTP {
                result = try await http.correct(zh: inputZh, en: inputEn, bankItemId: currentBankItemId, deviceId: DeviceID.current)
            } else {
                result = try await self.service.correct(zh: inputZh, en: inputEn)
            }
            self.response = result.response
            AppLog.aiInfo("Correction success: score=\(result.response.score), errors=\(result.response.errors.count)")
            if let hs = result.originalHighlights { self.highlights = hs }
            else if let res = self.response { self.highlights = Highlighter.computeHighlights(text: inputEn, errors: res.errors) }
            if let hs2 = result.correctedHighlights { self.correctedHighlights = hs2 }
            else if let res = self.response { self.correctedHighlights = Highlighter.computeHighlightsInCorrected(text: res.corrected, errors: res.errors) }
            self.selectedErrorID = self.response?.errors.first?.id
            // Notify completion for banner/notification consumers
            NotificationCenter.default.post(name: .correctionCompleted, object: nil, userInfo: [
                AppEventKeys.workspaceID: self.workspaceID,
                AppEventKeys.score: self.response?.score ?? 0,
                AppEventKeys.errors: self.response?.errors.count ?? 0,
            ])
        } catch {
            self.errorMessage = (error as NSError).localizedDescription
            AppLog.aiError("Correction failed: \((error as NSError).localizedDescription)")
        }
        isLoading = false
    }

    // 題庫開始練習：設定中文、提示、聚焦與 bankItemId
    func startPractice(with item: BankItem, tag: String? = nil) {
        // 填入新題目內容
        inputZh = item.zh
        practicedHints = item.hints
        showPracticedHints = false
        currentBankItemId = item.id
        currentPracticeTag = tag ?? (item.tags?.first)
        // 清空上一題的英文輸入與批改結果，避免殘留造成混淆
        inputEn = ""
        response = nil
        highlights = []
        correctedHighlights = []
        selectedErrorID = nil
        filterType = nil
        cardMode = .original
        requestFocusEn()
    }

    // 抽下一題（略過已完成），依目前練習標籤
    func loadNextPractice() async {
        guard AppConfig.backendURL != nil else {
            await MainActor.run { self.errorMessage = "BACKEND_URL 未設定" }
            return
        }
        let service = BankService()
        do {
            let next = try await service.fetchRandom(difficulty: nil, tag: currentPracticeTag, deviceId: DeviceID.current, skipCompleted: true)
            await MainActor.run {
                self.startPractice(with: next, tag: self.currentPracticeTag)
                self.inputEn = ""
                self.response = nil
                self.highlights = []
                self.correctedHighlights = []
                self.selectedErrorID = nil
                self.filterType = nil
                self.cardMode = .original
            }
        } catch {
            await MainActor.run {
                self.errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    var filteredErrors: [ErrorItem] {
        guard let res = response else { return [] }
        guard let f = filterType else { return res.errors }
        return res.errors.filter { $0.type == f }
    }

    var filteredHighlights: [Highlight] {
        guard let f = filterType else { return highlights }
        return highlights.filter { $0.type == f }
    }
    var filteredCorrectedHighlights: [Highlight] {
        guard let f = filterType else { return correctedHighlights }
        return correctedHighlights.filter { $0.type == f }
    }

    func applySuggestion(for error: ErrorItem) {
        guard let suggestion = error.suggestion, !suggestion.isEmpty else { return }
        guard let range = Highlighter.range(for: error, in: inputEn) else { return }
        inputEn.replaceSubrange(range, with: suggestion)
        // 重新計算高亮
        if let res = response {
            self.highlights = Highlighter.computeHighlights(text: inputEn, errors: res.errors)
            self.correctedHighlights = Highlighter.computeHighlightsInCorrected(text: res.corrected, errors: res.errors)
        }
    }

    private func persistResponse() {
        let ud = UserDefaults.standard
        if let res = response, let data = try? JSONEncoder().encode(res) {
            ud.set(data, forKey: keyResponse)
        } else {
            ud.removeObject(forKey: keyResponse)
        }
    }

    private func persistHints() {
        let ud = UserDefaults.standard
        if practicedHints.isEmpty {
            ud.removeObject(forKey: keyHints)
            return
        }
        if let data = try? JSONEncoder().encode(practicedHints) {
            ud.set(data, forKey: keyHints)
        }
    }
}

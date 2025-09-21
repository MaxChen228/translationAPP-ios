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
    // 題庫上下文（教師建議文字；非結構化）
    private var currentBankSuggestionText: String? = nil

    // 練習來源（遠端題庫或本機題庫）
    enum PracticeSource: Equatable { case local(bookName: String) }
    @Published var practiceSource: PracticeSource? = nil
    weak var localBankStore: LocalBankStore? = nil
    weak var localProgressStore: LocalBankProgressStore? = nil
    weak var practiceRecordsStore: PracticeRecordsStore? = nil

    // 練習會話追蹤
    private var practiceStartTime: Date? = nil

    func bindLocalBankStores(localBank: LocalBankStore, progress: LocalBankProgressStore) {
        self.localBankStore = localBank
        self.localProgressStore = progress
    }

    func bindPracticeRecordsStore(_ store: PracticeRecordsStore) {
        self.practiceRecordsStore = store
    }


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

        // 重新計算highlight（從已恢復的response和inputEn）
        if let res = self.response, !inputEn.isEmpty {
            self.highlights = Highlighter.computeHighlights(text: inputEn, errors: res.errors)
            self.correctedHighlights = Highlighter.computeHighlightsInCorrected(text: res.corrected, errors: res.errors)
        }

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
        currentBankSuggestionText = nil
        // 同步清掉持久化，符合「除非按右下角刪除才清空」
        let ud = UserDefaults.standard
        ud.removeObject(forKey: keyInputZh)
        ud.removeObject(forKey: keyInputEn)
        ud.removeObject(forKey: keyResponse)
        ud.removeObject(forKey: keyHints)
        ud.removeObject(forKey: keyShowHints)
    }

    func fillExample() {
        inputZh = String(localized: "content.sample.zh")
        inputEn = String(localized: "content.sample.en")
    }

    func requestFocusEn() {
        focusEnSignal &+= 1
    }

    // 移除舊的 Sheet 題庫流程；改為列表頁直接回填中文

    // 真實批改（需設定 BACKEND_URL；未設定時 UI 會提示並略過）
    func runCorrection() async {
        let user = inputEn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty else {
            let err = ErrorItem(
                id: UUID(),
                span: "",
                type: .pragmatic,
                explainZh: String(localized: "content.error.emptyInput"),
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

        if inputZh.isEmpty { inputZh = String(localized: "content.sample.zh") }

        isLoading = true
        errorMessage = nil
        do {
            AppLog.aiInfo("Start correction via \(String(describing: type(of: self.service)))")
            let result: AICorrectionResult
            if let http = self.service as? AIServiceHTTP {
                result = try await http.correct(
                    zh: inputZh,
                    en: inputEn,
                    bankItemId: currentBankItemId,
                    deviceId: DeviceID.current,
                    hints: practicedHints,
                    suggestion: currentBankSuggestionText
                )
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
            // 若為本機練習，更新本機完成度
            if case .local(let bookName) = self.practiceSource, let iid = self.currentBankItemId {
                self.localProgressStore?.markCompleted(book: bookName, itemId: iid, score: self.response?.score)
            }
            // Notify completion for banner/notification consumers
            NotificationCenter.default.post(name: .correctionCompleted, object: nil, userInfo: [
                AppEventKeys.workspaceID: self.workspaceID,
                AppEventKeys.score: self.response?.score ?? 0,
                AppEventKeys.errors: self.response?.errors.count ?? 0,
            ])
        } catch {
            self.errorMessage = (error as NSError).localizedDescription
            AppLog.aiError("Correction failed: \((error as NSError).localizedDescription)")
            // Notify failure so App can surface a banner
            NotificationCenter.default.post(name: .correctionFailed, object: nil, userInfo: [
                AppEventKeys.workspaceID: self.workspaceID,
                AppEventKeys.error: (error as NSError).localizedDescription
            ])
        }
        isLoading = false
    }

    // （移除遠端題庫練習入口）

    func startLocalPractice(bookName: String, item: BankItem, tag: String? = nil) {
        // 填入新題目內容
        inputZh = item.zh
        practicedHints = item.hints
        showPracticedHints = false
        currentBankItemId = item.id
        currentPracticeTag = tag ?? (item.tags?.first)
        practiceSource = .local(bookName: bookName)
        // 教師 suggestion 為單段文字
        currentBankSuggestionText = item.suggestion
        // 清空上一題的英文輸入與批改結果
        inputEn = ""
        response = nil
        highlights = []
        correctedHighlights = []
        selectedErrorID = nil
        filterType = nil
        cardMode = .original
        // 記錄練習開始時間
        practiceStartTime = Date()
        requestFocusEn()
    }

    // 抽下一題（本機）：依目前練習的本機書本挑選未完成題
    func loadNextPractice() async {
        guard case .local(let bookName) = practiceSource else {
            await MainActor.run { self.errorMessage = String(localized: "practice.error.notLocal") }
            return
        }
        guard let bank = localBankStore, let progress = localProgressStore else {
            await MainActor.run { self.errorMessage = String(localized: "practice.error.storeMissing") }
            return
        }
        let items = bank.items(in: bookName)
        if let next = items.first(where: { !progress.isCompleted(book: bookName, itemId: $0.id) && $0.id != self.currentBankItemId })
            ?? items.first(where: { !progress.isCompleted(book: bookName, itemId: $0.id) }) {
            await MainActor.run { self.startLocalPractice(bookName: bookName, item: next, tag: next.tags?.first) }
        } else {
            await MainActor.run { self.errorMessage = String(localized: "practice.error.noneRemaining") }
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

    // （提示陣列直接送後端解碼，無需組字串）

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

    // 保存練習記錄
    func savePracticeRecord() {
        guard let response = self.response,
              let store = practiceRecordsStore else { return }

        let startTime = practiceStartTime ?? Date()
        let bankBookName: String? = if case .local(let bookName) = practiceSource { bookName } else { nil }

        let record = PracticeRecord(
            createdAt: startTime,
            completedAt: Date(),
            bankItemId: currentBankItemId,
            bankBookName: bankBookName,
            practiceTag: currentPracticeTag,
            chineseText: inputZh,
            englishInput: inputEn,
            hints: practicedHints,
            teacherSuggestion: currentBankSuggestionText,
            correctedText: response.corrected,
            score: response.score,
            errors: response.errors
        )

        store.add(record)
        AppLog.aiInfo("Practice record saved: score=\(response.score), errors=\(response.errors.count)")
    }
}

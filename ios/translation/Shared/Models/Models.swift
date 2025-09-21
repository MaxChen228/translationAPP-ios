import SwiftUI

// 五大錯誤類型（直接用這五種，不再映射）
enum ErrorType: String, Codable, CaseIterable, Identifiable {
    case morphological      // 形態：單複數、時態
    case syntactic          // 句法：語序、子句
    case lexical            // 詞彙：用錯詞
    case phonological       // 語音/拼寫
    case pragmatic          // 語用：禮貌/語境

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .morphological: return LocalizedStringKey("error.type.morphological")
        case .syntactic: return LocalizedStringKey("error.type.syntactic")
        case .lexical: return LocalizedStringKey("error.type.lexical")
        case .phonological: return LocalizedStringKey("error.type.phonological")
        case .pragmatic: return LocalizedStringKey("error.type.pragmatic")
        }
    }

    var color: Color {
        let b = DS.Brand.scheme
        switch self {
        case .morphological: return b.classicBlue
        case .syntactic: return b.monument
        case .lexical: return b.provence
        case .phonological: return b.babyBlue
        case .pragmatic: return b.stucco
        }
    }
}

struct ErrorHints: Codable, Equatable {
    var before: String?
    var after: String?
    // 第 N 次匹配（1-based）
    var occurrence: Int?
}

struct ErrorItem: Identifiable, Codable, Equatable {
    let id: UUID
    var span: String
    var type: ErrorType
    var explainZh: String
    var suggestion: String?
    var hints: ErrorHints?
}

struct AIResponse: Codable, Equatable {
    var corrected: String
    var score: Int
    var errors: [ErrorItem]
}

// 高亮區段（在使用者英文中的 Range 與樣式）
struct Highlight: Identifiable, Equatable {
    let id: UUID
    let range: Range<String.Index>
    let type: ErrorType
}

//（保留擴充點：若未來需要細分，可在此擴充）

struct BankHint: Codable, Identifiable, Equatable {
    var id: UUID { UUID() }
    var category: ErrorType
    var text: String
}

struct BankSuggestion: Codable, Identifiable, Equatable {
    var id: UUID { UUID() }
    var text: String
    var category: String? = nil
}

struct BankItem: Codable, Identifiable, Equatable {
    var id: String
    var zh: String
    var hints: [BankHint]
    var suggestions: [BankSuggestion]
    // 教師提示（非結構化段落），作為批改上下文提供給後端
    var suggestion: String? = nil
    var tags: [String]? = nil
    var difficulty: Int = 1 // 1-5
    // 後端若帶 completed（需附 deviceId 查詢）
    var completed: Bool? = nil
}

// 練習記錄：保存完整的練習會話數據
struct PracticeRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let completedAt: Date

    // 練習來源信息
    let bankItemId: String?
    let bankBookName: String?
    let practiceTag: String?

    // 練習內容
    let chineseText: String
    let englishInput: String
    let hints: [BankHint]
    let teacherSuggestion: String?

    // 批改結果
    let correctedText: String
    let score: Int
    let errors: [ErrorItem]

    // 元數據
    let attemptCount: Int

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        completedAt: Date = Date(),
        bankItemId: String? = nil,
        bankBookName: String? = nil,
        practiceTag: String? = nil,
        chineseText: String,
        englishInput: String,
        hints: [BankHint] = [],
        teacherSuggestion: String? = nil,
        correctedText: String,
        score: Int,
        errors: [ErrorItem],
        attemptCount: Int = 1
    ) {
        self.id = id
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.bankItemId = bankItemId
        self.bankBookName = bankBookName
        self.practiceTag = practiceTag
        self.chineseText = chineseText
        self.englishInput = englishInput
        self.hints = hints
        self.teacherSuggestion = teacherSuggestion
        self.correctedText = correctedText
        self.score = score
        self.errors = errors
        self.attemptCount = attemptCount
    }
}

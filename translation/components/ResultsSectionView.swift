import SwiftUI

struct ResultsSectionView: View {
    let res: AIResponse
    let inputZh: String
    let inputEn: String
    let highlights: [Highlight]
    let correctedHighlights: [Highlight]
    let errors: [ErrorItem]
    @Binding var selectedErrorID: UUID?
    @Binding var filterType: ErrorType?
    @Binding var popoverError: ErrorItem?
    @Binding var mode: ResultSwitcherCard.Mode
    let applySuggestion: (ErrorItem) -> Void
    let onSave: (ErrorItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ResultSwitcherCard(
                score: res.score,
                grade: grade(for: res.score),
                inputZh: inputZh,
                inputEn: inputEn,
                corrected: res.corrected,
                originalHighlights: highlights,
                correctedHighlights: correctedHighlights,
                selectedErrorID: selectedErrorID,
                mode: $mode
            )

            DSSectionHeader(title: "錯誤列表", subtitle: "點擊項目聚焦對應高亮", accentUnderline: true)
            TypeChipsView(errors: res.errors, selection: $filterType)

            if errors.isEmpty {
                DSCard { Text("未偵測到錯誤。").foregroundStyle(.secondary) }
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(errors) { err in
                        ErrorItemRow(err: err, selected: selectedErrorID == err.id, onSave: { item in
                            onSave(item)
                        })
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 只聚焦對應高亮，不再開啟詳情畫面
                            selectedErrorID = err.id
                        }
                    }
                }
            }
        }
    }

    private func grade(for score: Int) -> String {
        switch score { case 90...: return "A"; case 80..<90: return "B"; case 70..<80: return "C"; case 60..<70: return "D"; default: return "E" }
    }
}

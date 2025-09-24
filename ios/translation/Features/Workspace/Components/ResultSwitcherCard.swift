import SwiftUI
import UIKit

struct ResultSwitcherCard: View {
    @Environment(\.locale) private var locale
    enum Mode: Int { case original = 0, corrected = 1 }

    var score: Int
    var grade: String
    var inputZh: String
    var inputEn: String
    var corrected: String

    var originalHighlights: [Highlight]
    var correctedHighlights: [Highlight]
    var selectedErrorID: UUID?

    @Binding var mode: Mode

    // copy 內文：一次複製三段（依當前語言顯示前綴）
    private var copyString: String {
        let zhPrefix = String(localized: "label.zhPrefix", locale: locale)
        let enOriginalPrefix = String(localized: "label.enOriginalPrefix", locale: locale)
        let enCorrectedPrefix = String(localized: "label.enCorrectedPrefix", locale: locale)
        return "\(zhPrefix)\n\(inputZh)\n\n\(enOriginalPrefix)\(inputEn)\n\n\(enCorrectedPrefix)\(corrected)"
    }

    var body: some View {
        DSCard {
            header
            ScoreBarView(score: score)
            contentPager
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            let key: LocalizedStringKey = (mode == .corrected) ? "result.switcher.corrected" : "result.switcher.original"
            Text(key)
                .dsType(DS.Font.section)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
            Spacer()
            HStack(spacing: DS.Spacing.sm2) {
                Button { UIPasteboard.general.string = copyString } label: { Image(systemName: "doc.on.doc") }
                ShareLink(item: copyString) { Image(systemName: "square.and.arrow.up") }
            }
            .buttonStyle(.plain)
        }
    }

    private var contentPager: some View {
        MorphingAnnotatedText(
                originalText: inputEn,
                correctedText: corrected,
                originalHighlights: originalHighlights,
                correctedHighlights: correctedHighlights,
                selectedID: selectedErrorID,
                isShowingCorrected: mode == .corrected
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let dx = value.translation.width
                    if dx < -30 { mode = .corrected } // swipe left
                    if dx > 30 { mode = .original }   // swipe right
                }
        )
    }
}

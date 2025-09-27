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
    var commentary: String? = nil

    @State private var isCommentaryExpanded: Bool = true

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
            commentarySection
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

    @ViewBuilder
    private var commentarySection: some View {
        let trimmed = commentary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Button {
                    withAnimation(DS.AnimationToken.subtle) {
                        isCommentaryExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        commentaryIcon
                        VStack(alignment: .leading, spacing: 2) {
                            Text("results.commentary.title")
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                            if !isCommentaryExpanded {
                                Text(trimmed)
                                    .dsType(DS.Font.body)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: isCommentaryExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isCommentaryExpanded {
                    Text(trimmed)
                        .dsType(DS.Font.body, lineSpacing: 4)
                        .foregroundStyle(.primary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(String(format: String(localized: "a11y.commentary", locale: locale), trimmed)))
        }
    }

    private var commentaryIcon: some View {
        ZStack {
            Circle()
                .fill(DS.Brand.scheme.babyBlue.opacity(0.25))
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.Brand.scheme.classicBlue)
        }
        .frame(width: 28, height: 28)
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

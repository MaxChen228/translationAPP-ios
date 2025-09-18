import SwiftUI
import UIKit

struct ResultSummaryCard: View {
    enum Style { case ring, compactBar }

    var score: Int
    var corrected: String
    var style: Style = .compactBar

    @State private var showCopied = false

    @Environment(\.locale) private var locale
    var body: some View {
        switch style {
        case .ring:
            DSCard {
                HStack(alignment: .top, spacing: DS.Spacing.lg) {
                    ScoreRingView(score: score)
                        .padding(6)
                        .background(Circle().fill(DS.Palette.surfaceAlt))
                    VStack(alignment: .leading, spacing: 8) {
                        headerActions
                        correctedText
                    }
                    Spacer()
                }
            }
        case .compactBar:
            DSCard {
                VStack(alignment: .leading, spacing: 12) {
                    headerActions
                    ScoreBarView(score: score)
                    correctedText
                }
            }
        }
    }

    private var headerActions: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("result.switcher.corrected")
                .dsType(DS.Font.section, tracking: 0.2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                UIPasteboard.general.string = corrected
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation(DS.AnimationToken.snappy) { showCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(DS.AnimationToken.subtle) { showCopied = false }
                }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("a11y.copyCorrected"))

            ShareLink(item: corrected) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
        }
        .overlay(alignment: .topTrailing) {
            if showCopied {
                Text(String(localized: "action.copied", locale: locale))
                    .dsType(DS.Font.caption)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var correctedText: some View {
        Text(corrected)
            .dsType(DS.Font.serifBody, lineSpacing: 6, tracking: 0.1)
            .foregroundStyle(.primary)
            .textSelection(.enabled)
    }
}

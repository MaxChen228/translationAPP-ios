import SwiftUI

struct FlashcardsSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("flashcards.reviewMode") private var modeRaw: String = FlashcardsReviewMode.browse.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("設定").dsType(DS.Font.section)
            VStack(alignment: .leading, spacing: 8) {
                Text("複習模式").dsType(DS.Font.caption).foregroundStyle(.secondary)
                Picker("複習模式", selection: $modeRaw) {
                    ForEach(FlashcardsReviewMode.allCases, id: \.rawValue) { m in
                        Text(m.rawValue).tag(m.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Text(helpText).dsType(DS.Font.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(DSPrimaryButton())
                    .frame(width: 120)
            }
        }
        .padding(16)
        .background(DS.Palette.background)
    }

    private var helpText: String {
        if modeRaw == FlashcardsReviewMode.annotate.rawValue {
            return "標注：右滑 +1，左滑 −1，並切到下一張。"
        } else {
            return "瀏覽：左右滑動切換卡片，不改精熟度。"
        }
    }
}


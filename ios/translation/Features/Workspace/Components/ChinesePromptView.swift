import SwiftUI

struct ChinesePromptView: View {
    var text: String

    var body: some View {
        Group {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("prompt.empty")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .stroke(DS.Palette.border.opacity(0.4), lineWidth: DS.BorderWidth.regular)
                    )
            } else {
                Text(text)
                    .dsType(DS.Font.serifTitle, lineSpacing: 6, tracking: 0.1)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .stroke(DS.Brand.scheme.babyBlue.opacity(0.45), lineWidth: DS.BorderWidth.regular)
                    )
                    .overlay(alignment: .leading) {
                        LinearGradient(colors: [DS.Brand.scheme.cornhusk, DS.Brand.scheme.peachQuartz], startPoint: .top, endPoint: .bottom)
                            .frame(width: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
                            .padding(.vertical, 6)
                    }
            }
        }
    }
}

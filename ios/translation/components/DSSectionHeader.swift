import SwiftUI

struct DSSectionHeader: View {
    var title: String
    var subtitle: String? = nil
    // 強調底線
    var accentUnderline: Bool = false
    var accentWidth: CGFloat = 36
    var accentHeight: CGFloat = 2
    var accentOpacity: Double = 0.6
    // 進階：讓底線長度自動對齊標題文字
    var accentMatchTitle: Bool = true
    var accentLines: Int = 1
    var accentSpacing: CGFloat = 3
    // 鋪色（在封閉區域內填充顏色）
    var accentFill: Bool = false
    var accentFillHeight: CGFloat = 10
    var accentFillOpacity: Double = 0.10

    @State private var subtitleWidth: CGFloat = 0
    @State private var titleWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .dsType(DS.Font.serifTitle)
                .fontWeight(.semibold)
                .background(WidthReader(width: $titleWidth))
            if accentUnderline {
                let w = (accentMatchTitle && titleWidth > 0) ? titleWidth : accentWidth
                ZStack(alignment: .bottomLeading) {
                    if accentFill {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(DS.Brand.scheme.babyBlue.opacity(accentFillOpacity))
                            .frame(width: w, height: accentFillHeight)
                    }
                    VStack(alignment: .leading, spacing: accentSpacing) {
                        ForEach(0..<(max(1, accentLines)), id: \.self) { i in
                            Capsule()
                                .fill(DS.Brand.scheme.cornhusk)
                                .opacity(i == 0 ? accentOpacity : max(0.35, accentOpacity - 0.2))
                                .frame(width: w, height: accentHeight)
                        }
                    }
                }
                .padding(.top, 2)
            }
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(DS.Palette.subdued)
                    .background(WidthReader(width: $subtitleWidth))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidthReader: View {
    @Binding var width: CGFloat
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: WidthPreferenceKey.self, value: geo.size.width)
        }
        .onPreferenceChange(WidthPreferenceKey.self) { self.width = $0 }
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

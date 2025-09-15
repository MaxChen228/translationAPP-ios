import SwiftUI
import UIKit

struct DSTextArea: View {
    @Binding var text: String
    var minHeight: CGFloat = 100
    var placeholder: String
    var isFocused: Bool = false
    var ruled: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if ruled {
                DSLinedBackground()
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .allowsHitTesting(false)
            }
            if text.isEmpty {
                Text(placeholder)
                    .dsType(DS.Font.body, lineSpacing: 4, tracking: 0.1)
                    .foregroundStyle(DS.Palette.subdued)
                    .padding(.top, 8)
                    .padding(.horizontal, 6)
            }
            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .font(DS.Font.body)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(isFocused ? DS.Palette.primary.opacity(0.45) : DS.Palette.border.opacity(0.35), lineWidth: DS.BorderWidth.regular)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

private struct DSLinedBackground: View {
    var body: some View {
        GeometryReader { geo in
            let step = DS.DSUIFont.body().lineHeight + 8
            let color = DS.Brand.scheme.babyBlue.opacity(0.18)
            Path { path in
                var y: CGFloat = 0
                while y <= geo.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    y += step
                }
            }
            .stroke(color, lineWidth: DS.BorderWidth.hairline)
        }
    }
}

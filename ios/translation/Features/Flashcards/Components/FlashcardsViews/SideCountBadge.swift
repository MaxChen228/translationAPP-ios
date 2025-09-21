import SwiftUI

struct SideCountBadge: View {
    let count: Int
    let color: Color
    var filled: Bool = false

    var body: some View {
        Text("\(count)")
            .dsType(DS.Font.labelMd)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.vertical, DS.Spacing.xs)
            .padding(.horizontal, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                    .stroke(color, lineWidth: DS.BorderWidth.regular)
            )
            .opacity(filled ? 1.0 : 0.6)
            .scaleEffect(filled ? 1.1 : 1.0)
            .dsAnimation(DS.AnimationToken.bouncy, value: filled)
            .dsAnimation(DS.AnimationToken.subtle, value: count)
    }
}

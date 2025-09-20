import SwiftUI

struct SideCountBadge: View {
    let count: Int
    let color: Color
    var filled: Bool = false

    var body: some View {
        Text("\(count)")
            .font(.headline).bold()
            .foregroundStyle(filled ? Color.white : .primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule().fill(filled ? color : color.opacity(0.12))
            )
            .overlay(
                Capsule().stroke(color.opacity(filled ? 0.0 : 0.6), lineWidth: DS.BorderWidth.regular)
            )
    }
}

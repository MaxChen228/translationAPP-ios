import SwiftUI

struct SuggestionChip: View {
    var text: String
    var color: Color
    var body: some View {
        Text(text)
            .dsType(DS.Font.mono)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: DS.BorderWidth.thin)
            )
    }
}

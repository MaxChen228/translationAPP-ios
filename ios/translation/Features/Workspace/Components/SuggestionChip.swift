import SwiftUI

struct SuggestionChip: View {
    var text: String
    var color: Color
    var body: some View {
        Text(text)
            .dsType(DS.Font.mono)
            .padding(.vertical, DS.Component.Chip.paddingVertical)
            .padding(.horizontal, DS.Component.Chip.paddingHorizontal)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(DS.Component.Chip.fillOpacity))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(color.opacity(DS.Component.Chip.strokeOpacity), lineWidth: DS.BorderWidth.thin)
            )
    }
}

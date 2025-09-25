import SwiftUI

struct DSTagLabel: View {
    private let text: Text
    private let color: Color

    init(titleKey: LocalizedStringKey, color: Color) {
        self.text = Text(titleKey)
        self.color = color
    }

    init(title: String, color: Color) {
        self.text = Text(title)
        self.color = color
    }

    var body: some View {
        text
            .dsType(DS.Font.caption)
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
            .foregroundStyle(color)
    }
}

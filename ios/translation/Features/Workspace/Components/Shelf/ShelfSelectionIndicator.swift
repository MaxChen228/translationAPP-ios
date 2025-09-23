import SwiftUI

struct ShelfSelectionIndicator: View {
    var isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(DS.Palette.background)
                .overlay(
                    Circle()
                        .stroke(DS.Palette.border.opacity(DS.Opacity.strong), lineWidth: DS.BorderWidth.thin)
                )
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)

            if isSelected {
                Circle()
                    .fill(DS.Palette.primary)
                    .padding(4)

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Palette.onPrimary)
            }
        }
        .frame(width: 24, height: 24)
    }
}

struct ShelfSelectableModifier: ViewModifier {
    var isEditing: Bool
    var isSelected: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if isEditing {
                    ShelfSelectionIndicator(isSelected: isSelected)
                        .padding(DS.Spacing.sm)
                }
            }
    }
}

extension View {
    func shelfSelectable(isEditing: Bool, isSelected: Bool) -> some View {
        modifier(ShelfSelectableModifier(isEditing: isEditing, isSelected: isSelected))
    }
}

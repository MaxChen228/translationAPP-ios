import SwiftUI

struct FlashcardsFlipCard<Front: View, Back: View, Overlay: View>: View {
    var isFlipped: Bool
    private let front: Front
    private let back: Back
    private let overlay: () -> Overlay

    init(
        isFlipped: Bool,
        @ViewBuilder front: () -> Front,
        @ViewBuilder back: () -> Back,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.isFlipped = isFlipped
        self.front = front()
        self.back = back()
        self.overlay = overlay
    }

    @ViewBuilder
    private func faceCard<Content: View>(_ content: Content) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            content
                .dsType(DS.Font.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.lg)
        .background(DS.Palette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.border, lineWidth: DS.BorderWidth.thin)
        )
        .frame(minHeight: 240)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) {
            overlay()
                .padding(.trailing, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.md)
        }
    }

    var body: some View {
        ZStack {
            faceCard(front)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
                .opacity(isFlipped ? 0 : 1)

            faceCard(back)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
                .opacity(isFlipped ? 1 : 0)
        }
        .dsAnimation(DS.AnimationToken.flip, value: isFlipped)
    }
}

import SwiftUI

struct LoadingOverlay: View {
    var textKey: LocalizedStringKey = "loading.correcting"
    var body: some View {
        ZStack {
            DS.Palette.scrim
                .ignoresSafeArea()
            VStack(spacing: DS.Spacing.sm2) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text(textKey)
                    .dsType(DS.Font.section)
            }
            .padding(.horizontal, DS.Component.OverlayCard.paddingHorizontal)
            .padding(.vertical, DS.Component.OverlayCard.paddingVertical)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: DS.Component.OverlayCard.cornerRadius, style: .continuous)
            )
            .shadow(color: DS.Shadow.overlay.color, radius: DS.Shadow.overlay.radius, x: DS.Shadow.overlay.x, y: DS.Shadow.overlay.y)
        }
        .transition(.opacity)
    }
}

#Preview { LoadingOverlay() }

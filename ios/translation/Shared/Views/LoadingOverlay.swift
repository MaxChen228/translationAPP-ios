import SwiftUI

struct LoadingOverlay: View {
    var textKey: LocalizedStringKey = "loading.correcting"
    var body: some View {
        ZStack {
            DS.Palette.scrim
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text(textKey)
                    .font(.headline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: DS.Shadow.overlay.color, radius: DS.Shadow.overlay.radius, x: DS.Shadow.overlay.x, y: DS.Shadow.overlay.y)
        }
        .transition(.opacity)
    }
}

#Preview { LoadingOverlay() }

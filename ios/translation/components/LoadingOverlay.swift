import SwiftUI

struct LoadingOverlay: View {
    var textKey: LocalizedStringKey = "loading.correcting"
    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
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
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 6)
        }
        .transition(.opacity)
    }
}

#Preview { LoadingOverlay() }

import SwiftUI

final class BannerCenter: ObservableObject {
    @Published var banner: BannerItem? = nil
    func show(title: String, subtitle: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        withAnimation(DS.AnimationToken.snappy) {
            banner = BannerItem(title: title, subtitle: subtitle, actionTitle: actionTitle, action: action)
        }
        // Auto dismiss after 2 seconds if no interaction
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            withAnimation(DS.AnimationToken.subtle) { self?.banner = nil }
        }
    }
}

struct BannerItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?
}

struct BannerHost: View {
    @EnvironmentObject var center: BannerCenter
    var body: some View {
        VStack {
            if let item = center.banner {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(DS.Palette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.headline)
                        if let s = item.subtitle { Text(s).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    if let t = item.actionTitle {
                        Button(t) { item.action?(); withAnimation(DS.AnimationToken.subtle) { center.banner = nil } }
                            .buttonStyle(DSSecondaryButtonCompact())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 6)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .allowsHitTesting(center.banner != nil)
        .animation(DS.AnimationToken.snappy, value: center.banner != nil)
    }
}

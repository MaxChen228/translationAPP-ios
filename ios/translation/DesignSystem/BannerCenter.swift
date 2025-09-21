import SwiftUI

final class BannerCenter: ObservableObject {
    @Published var banner: BannerItem? = nil
    func show(title: String, subtitle: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        DSMotion.run(DS.AnimationToken.snappy) {
            banner = BannerItem(title: title, subtitle: subtitle, actionTitle: actionTitle, action: action)
        }
        // Auto dismiss after user-configured seconds (defaults to 2s)
        let seconds = UserDefaults.standard.object(forKey: "settings.bannerSeconds") as? Double ?? 2.0
        let delay = max(0.5, min(10.0, seconds))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            DSMotion.run(DS.AnimationToken.subtle) { self?.banner = nil }
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
        ZStack(alignment: .bottomTrailing) {
            if let item = center.banner {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(DS.Palette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.headline)
                        if let s = item.subtitle { Text(s).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    if let t = item.actionTitle {
                        Spacer(minLength: 8)
                        Button(t) { item.action?(); DSMotion.run(DS.AnimationToken.subtle) { center.banner = nil } }
                            .buttonStyle(DSButton(style: .secondary, size: .compact))
                    }
                }
                .padding(.horizontal, DS.Spacing.md2)
                .padding(.vertical, DS.Spacing.sm)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md2, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                // keep it off the edges (bottom-right corner)
                .padding(.trailing, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
                .transition(DSTransition.slideTrailingFade)
                .frame(maxWidth: 360, alignment: .trailing)
            }
        }
        // Ensure the host fills the available screen so bottomTrailing alignment works
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .allowsHitTesting(center.banner != nil)
        .dsAnimation(DS.AnimationToken.snappy, value: center.banner != nil)
    }
}

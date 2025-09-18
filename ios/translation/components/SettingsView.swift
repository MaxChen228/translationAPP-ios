import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSSectionHeader(title: String(localized: "settings.banner.title", locale: locale), subtitle: String(localized: "settings.banner.subtitle", locale: locale), accentUnderline: true)
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(String(localized: "settings.banner.seconds", locale: locale)).dsType(DS.Font.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1fs", settings.bannerSeconds)).dsType(DS.Font.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(get: { settings.bannerSeconds }, set: { settings.bannerSeconds = $0 }), in: 0.5...5.0, step: 0.5)
                            .tint(DS.Palette.primary)
                        HStack {
                            Spacer()
                            Button(String(localized: "settings.banner.test", locale: locale)) {
                                bannerCenter.show(title: String(localized: "settings.banner.test", locale: locale), subtitle: String(format: "%.1fs", settings.bannerSeconds))
                            }
                            .buttonStyle(DSSecondaryButtonCompact())
                        }
                    }
                }

                DSSectionHeader(title: String(localized: "settings.model.title", locale: locale), subtitle: String(localized: "settings.model.subtitle", locale: locale), accentUnderline: true)
                DSOutlineCard {
                    Picker("Model", selection: Binding(get: { settings.geminiModel }, set: { settings.geminiModel = $0 })) {
                        ForEach(AppSettingsStore.availableModels, id: \.self) { m in
                            Text(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(DS.Palette.primary)
                }

                DSSectionHeader(title: String(localized: "settings.language.title", locale: locale), subtitle: String(localized: "settings.language.subtitle", locale: locale), accentUnderline: true)
                DSOutlineCard {
                    Picker("Language", selection: Binding(get: { settings.language }, set: { settings.language = $0 })) {
                        ForEach(AppSettingsStore.availableLanguages, id: \.code) { item in
                            Text(item.label).tag(item.code)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(DS.Palette.primary)
                }

                DSSectionHeader(title: String(localized: "settings.device.title", locale: locale), subtitle: nil, accentUnderline: true)
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(String(localized: "settings.device.id", locale: locale)).dsType(DS.Font.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(settings.deviceID)
                                .font(DS.Font.monoSmall)
                                .multilineTextAlignment(.trailing)
                                .textSelection(.enabled)
                        }
                        HStack {
                            Spacer()
                            Button(String(localized: "action.copy", locale: locale)) {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = settings.deviceID
                                #endif
                                Haptics.success()
                                bannerCenter.show(title: String(localized: "msg.copiedDeviceID", locale: locale))
                            }
                            .buttonStyle(DSSecondaryButtonCompact())
                        }
                        DSSeparator()
                        HStack {
                            Text(String(localized: "label.version", locale: locale)).dsType(DS.Font.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(settings.appVersion).dsType(DS.Font.caption)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle(String(localized: "nav.settings", locale: locale))
    }
}

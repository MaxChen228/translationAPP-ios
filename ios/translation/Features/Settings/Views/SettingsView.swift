import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @EnvironmentObject private var progressStore: FlashcardProgressStore
    @Environment(\.locale) private var locale
    @State private var showResetConfirm: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Flashcards
                DSSectionHeader(titleKey: "settings.flashcards.title", subtitleKey: "settings.flashcards.subtitle", accentUnderline: true)
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("settings.flashcards.reset.hint").dsType(DS.Font.caption).foregroundStyle(.secondary)
                        HStack { Spacer()
                            Button(role: .destructive) { showResetConfirm = true } label: { Text("settings.flashcards.resetAll") }
                                .buttonStyle(DSButton(style: .secondary, size: .full))
                        }
                    }
                }

                DSSectionHeader(titleKey: "settings.practice.title", subtitleKey: "settings.practice.subtitle", accentUnderline: true)
                DSOutlineCard {
                    Toggle(isOn: Binding(get: { settings.autoSavePracticeRecords }, set: { settings.autoSavePracticeRecords = $0 })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("settings.practice.autoSave.title")
                                .dsType(DS.Font.body)
                                .foregroundStyle(.primary)
                            Text("settings.practice.autoSave.caption")
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: DS.Palette.primary))
                }

                DSSectionHeader(titleKey: "settings.banner.title", subtitleKey: "settings.banner.subtitle", accentUnderline: true)
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("settings.banner.seconds").dsType(DS.Font.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1fs", settings.bannerSeconds)).dsType(DS.Font.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(get: { settings.bannerSeconds }, set: { settings.bannerSeconds = $0 }), in: 0.5...5.0, step: 0.5)
                            .tint(DS.Palette.primary)
                        HStack {
                            Spacer()
                            Button(action: { bannerCenter.show(title: String(localized: "settings.banner.test"), subtitle: String(format: "%.1fs", settings.bannerSeconds)) }) { Text("settings.banner.test") }
                            .buttonStyle(DSButton(style: .secondary, size: .compact))
                        }
                    }
                }

                DSSectionHeader(titleKey: "settings.aiModels.title", subtitleKey: "settings.aiModels.subtitle", accentUnderline: true)
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 16) {
                        // Correction Model
                        VStack(alignment: .leading, spacing: 8) {
                            Text("settings.aiModels.correction").dsType(DS.Font.body).foregroundStyle(.primary)
                            Picker("Correction Model", selection: Binding(get: { settings.correctionModel }, set: { settings.correctionModel = $0 })) {
                                ForEach(AppSettingsStore.availableModels) { option in
                                    Text(option.labelKey).tag(option.value)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(DS.Palette.primary)
                        }

                        DSSeparator()

                        // Deck Generation Model
                        VStack(alignment: .leading, spacing: 8) {
                            Text("settings.aiModels.deckGeneration").dsType(DS.Font.body).foregroundStyle(.primary)
                            Picker("Deck Generation Model", selection: Binding(get: { settings.deckGenerationModel }, set: { settings.deckGenerationModel = $0 })) {
                                ForEach(AppSettingsStore.availableModels) { option in
                                    Text(option.labelKey).tag(option.value)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(DS.Palette.primary)
                        }

                        DSSeparator()

                        // Chat Response Model
                        VStack(alignment: .leading, spacing: 8) {
                            Text("settings.aiModels.chatResponse").dsType(DS.Font.body).foregroundStyle(.primary)
                            Picker("Chat Response Model", selection: Binding(get: { settings.chatResponseModel }, set: { settings.chatResponseModel = $0 })) {
                                ForEach(AppSettingsStore.availableModels) { option in
                                    Text(option.labelKey).tag(option.value)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(DS.Palette.primary)
                        }

                        DSSeparator()

                        // Research Model
                        VStack(alignment: .leading, spacing: 8) {
                            Text("settings.aiModels.research").dsType(DS.Font.body).foregroundStyle(.primary)
                            Picker("Research Model", selection: Binding(get: { settings.researchModel }, set: { settings.researchModel = $0 })) {
                                ForEach(AppSettingsStore.availableModels) { option in
                                    Text(option.labelKey).tag(option.value)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(DS.Palette.primary)
                        }
                    }
                }

                DSSectionHeader(titleKey: "settings.language.title", subtitleKey: "settings.language.subtitle", accentUnderline: true)
                DSOutlineCard {
                    let langOptions: [(code: String, key: LocalizedStringKey)] = [("zh", "settings.language.zh"), ("en", "settings.language.en")]
                    Picker("Language", selection: Binding(get: { settings.language }, set: { settings.language = $0 })) {
                        ForEach(langOptions, id: \.code) { opt in
                            Text(opt.key).tag(opt.code)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(DS.Palette.primary)
                }

                DSSectionHeader(titleKey: "settings.device.title", subtitleKey: nil, accentUnderline: true)
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("settings.device.id").dsType(DS.Font.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(settings.deviceID)
                                .font(DS.Font.monoSmall)
                                .multilineTextAlignment(.trailing)
                                .textSelection(.enabled)
                        }
                        HStack {
                            Spacer()
                            Button(action: {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = settings.deviceID
                                #endif
                                Haptics.success()
                                bannerCenter.show(title: String(localized: "msg.copiedDeviceID"))
                            }) { Text("action.copy") }
                            .buttonStyle(DSButton(style: .secondary, size: .compact))
                        }
                        DSSeparator()
                        HStack {
                            Text("label.version").dsType(DS.Font.caption).foregroundStyle(.secondary)
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
        .navigationTitle(Text("nav.settings"))
        .id(locale.identifier)
        .alert(Text("settings.flashcards.reset.confirm.title"), isPresented: $showResetConfirm) {
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {}
            Button(String(localized: "action.delete", locale: locale), role: .destructive) { progressStore.clearAll(); bannerCenter.show(title: String(localized: "settings.flashcards.reset.done", locale: locale)) }
        } message: {
            Text("settings.flashcards.reset.confirm.subtitle")
        }
    }
}

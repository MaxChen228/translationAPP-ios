import SwiftUI

struct FlashcardsSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("flashcards.reviewMode") private var modeRaw: String = FlashcardsReviewMode.browse.storageValue
    @Environment(\.locale) private var locale
    @EnvironmentObject private var progressStore: FlashcardProgressStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @ObservedObject var ttsStore: TTSSettingsStore
    var onOpenAudio: (() -> Void)? = nil
    var onShuffle: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil
    @State private var showResetConfirm: Bool = false
    @State private var showShuffleSuccess: Bool = false
    @State private var shuffleSpin: Bool = false
    @State private var showAdvancedSettings: Bool = false

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("nav.settings").dsType(DS.Font.section)
            VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                Text("flashcards.settings.mode").dsType(DS.Font.caption).foregroundStyle(.secondary)
                Picker("flashcards.settings.mode", selection: $modeRaw) {
                    ForEach(FlashcardsReviewMode.allCases, id: \.storageValue) { m in
                        Text(m.labelKey).tag(m.storageValue)
                    }
                }
                .pickerStyle(.segmented)
                Text(helpText).dsType(DS.Font.caption).foregroundStyle(.secondary)
            }

            FieldSettingsSection(store: ttsStore)

            AdvancedSettingsCard(store: ttsStore, isExpanded: $showAdvancedSettings, onOpenAudio: onOpenAudio)

            DSOutlineCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("settings.flashcards.reset.hint").dsType(DS.Font.caption).foregroundStyle(.secondary)
                    HStack(spacing: DS.Spacing.md) {
                        Button {
                            guard onShuffle != nil else { return }
                            onShuffle?()
                            Haptics.selection()
                            shuffleSpin.toggle()
                            withAnimation(DS.AnimationToken.subtle) {
                                showShuffleSuccess = true
                            }
                            bannerCenter.show(title: String(localized: "flashcards.shuffle.done", locale: locale))
                            Task {
                                try? await Task.sleep(nanoseconds: 1_200_000_000)
                                await MainActor.run {
                                    withAnimation(DS.AnimationToken.subtle) {
                                        showShuffleSuccess = false
                                    }
                                }
                            }
                        } label: {
                            Label {
                                Text("flashcards.shuffle")
                            } icon: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .rotationEffect(.degrees(shuffleSpin ? 360 : 0))
                                    .animation(.easeInOut(duration: 0.65), value: shuffleSpin)
                            }
                        }
                        .buttonStyle(DSButton(style: .secondary, size: .full))
                        .disabled(onShuffle == nil)

                        Button(role: .destructive) { showResetConfirm = true } label: {
                            Text("settings.flashcards.resetAll")
                        }
                        .buttonStyle(DSButton(style: .secondary, size: .full))
                    }
                    .frame(maxWidth: .infinity)
                    if showShuffleSuccess {
                        Text(String(localized: "flashcards.shuffle.done", locale: locale))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(DS.Palette.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }
                }
            }

            HStack { Spacer()
                Button(String(localized: "action.done", locale: locale)) {
                    onDone?()
                    dismiss()
                }
                    .buttonStyle(DSButton(style: .secondary, size: .full))
                    .frame(width: DS.ButtonSize.medium)
            }
        }
        .padding(DS.Spacing.md)
        }
        .background(DS.Palette.background)
        .alert(Text("settings.flashcards.reset.confirm.title"), isPresented: $showResetConfirm) {
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {}
            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                progressStore.clearAll()
                Haptics.success()
                bannerCenter.show(title: String(localized: "settings.flashcards.reset.done", locale: locale))
            }
        } message: {
            Text("settings.flashcards.reset.confirm.subtitle")
        }
    }

    private var helpText: String {
        if FlashcardsReviewMode.fromStorage(modeRaw) == .annotate {
            return String(localized: "flashcards.settings.help.annotate", locale: locale)
        } else {
            return String(localized: "flashcards.settings.help.browse", locale: locale)
        }
    }
}

private struct FieldSettingsSection: View {
    @ObservedObject var store: TTSSettingsStore

    var body: some View {
        let snapshot = store.settings
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
                Text(String(localized: "tts.fieldSettings.title", defaultValue: "Field playback"))
                    .dsType(DS.Font.section)
                Text(String(localized: "tts.fieldSettings.subtitle", defaultValue: "Choose which parts to read and fine-tune each section."))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(TTSField.allCases.enumerated()), id: \.element.id) { index, field in
                    FieldSettingsRow(
                        field: field,
                        config: binding(for: field),
                        globalRate: snapshot.rate,
                        globalGap: snapshot.segmentGap
                    )
                    if index != TTSField.allCases.count - 1 {
                        Divider().padding(.vertical, DS.Spacing.xs)
                    }
                }
            }
        }
    }

    private func binding(for field: TTSField) -> Binding<TTSFieldSettings> {
        Binding(
            get: { store.settings.fieldConfig(for: field) },
            set: { newValue in
                var s = store.settings
                s.fieldSettings[field] = newValue
                store.settings = s
            }
        )
    }
}

private struct FieldSettingsRow: View {
    let field: TTSField
    @Binding var config: TTSFieldSettings
    var globalRate: Float
    var globalGap: Double

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
            Toggle(isOn: $config.enabled) {
                Text(field.localizedTitle)
                    .dsType(DS.Font.bodyEmph)
            }
            .toggleStyle(SwitchToggleStyle(tint: DS.Palette.primary))

            if config.enabled {
                let useCustomRate = Binding<Bool>(
                    get: { config.rateOverride != nil },
                    set: { newValue in
                        if newValue {
                            config.rateOverride = config.rateOverride ?? globalRate
                        } else {
                            config.rateOverride = nil
                        }
                    }
                )

                let rateBinding = Binding<Double>(
                    get: { Double(config.rateOverride ?? globalRate) },
                    set: { config.rateOverride = Float($0) }
                )

                let useCustomGap = Binding<Bool>(
                    get: { config.gapOverride != nil },
                    set: { newValue in
                        if newValue {
                            config.gapOverride = config.gapOverride ?? globalGap
                        } else {
                            config.gapOverride = nil
                        }
                    }
                )

                let gapBinding = Binding<Double>(
                    get: { config.gapOverride ?? globalGap },
                    set: { config.gapOverride = $0 }
                )

                VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                    Toggle(isOn: useCustomRate) {
                        Text(String(localized: "tts.field.customRate", defaultValue: "Custom rate"))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                    if useCustomRate.wrappedValue {
                        Slider(value: rateBinding, in: 0.3...0.6)
                            .tint(DS.Palette.primary)
                        Text(String(format: "%.2fx", rateBinding.wrappedValue))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(format: String(localized: "tts.field.followGlobalRate", defaultValue: "Follow global (%.2fx)"), globalRate))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle(isOn: useCustomGap) {
                        Text(String(localized: "tts.field.customGap", defaultValue: "Custom pause"))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                    if useCustomGap.wrappedValue {
                        Slider(value: gapBinding, in: 0...2, step: 0.1)
                            .tint(DS.Palette.primary)
                        Text(String(format: "%.1fs", gapBinding.wrappedValue))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(format: String(localized: "tts.field.followGlobalGap", defaultValue: "Follow global (%.1fs)"), globalGap))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, DS.Spacing.sm)
            }
        }
    }
}

private struct AdvancedSettingsCard: View {
    @ObservedObject var store: TTSSettingsStore
    @Binding var isExpanded: Bool
    var onOpenAudio: (() -> Void)?

    var body: some View {
        let snapshot = store.settings
        DSOutlineCard {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
                    Text(String(localized: "tts.order")).dsType(DS.Font.caption).foregroundStyle(.secondary)
                    Picker("tts.order", selection: Binding(get: { store.settings.readOrder }, set: { store.settings.readOrder = $0 })) {
                        ForEach(ReadOrder.allCases) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(DS.Palette.primary)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                        HStack {
                            Text("tts.rate").dsType(DS.Font.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2fx", store.settings.rate)).dsType(DS.Font.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(get: { Double(store.settings.rate) }, set: { store.settings.rate = Float($0) }), in: 0.3...0.6)
                            .tint(DS.Palette.primary)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                        HStack {
                            Text("tts.segmentGap").dsType(DS.Font.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1fs", store.settings.segmentGap)).dsType(DS.Font.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(get: { store.settings.segmentGap }, set: { store.settings.segmentGap = $0 }), in: 0...2, step: 0.1)
                            .tint(DS.Palette.primary)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                        HStack {
                            Text("tts.cardGap").dsType(DS.Font.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1fs", store.settings.cardGap)).dsType(DS.Font.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(get: { store.settings.cardGap }, set: { store.settings.cardGap = $0 }), in: 0...3, step: 0.1)
                            .tint(DS.Palette.primary)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                        Text("tts.variantFill").dsType(DS.Font.caption).foregroundStyle(.secondary)
                        Picker("tts.variantFill", selection: Binding(get: { store.settings.variantFill }, set: { store.settings.variantFill = $0 })) {
                            ForEach(VariantFill.allCases) { fill in
                                Text(fill.displayName).tag(fill)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(DS.Palette.primary)
                    }

                    if let onOpenAudio {
                        Button(String(localized: "tts.openAudioPanel", defaultValue: "Open audio controls")) {
                            onOpenAudio()
                        }
                        .buttonStyle(DSButton(style: .secondary, size: .full))
                    }
                }
                .padding(.top, DS.Spacing.sm)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(localized: "tts.advanced.title", defaultValue: "Advanced playback"))
                        .dsType(DS.Font.section)
                    Spacer()
                    Text(summary(from: snapshot))
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func summary(from settings: TTSSettings) -> String {
        String(format: "%.2fx • %.1fs", settings.rate, settings.segmentGap)
    }
}

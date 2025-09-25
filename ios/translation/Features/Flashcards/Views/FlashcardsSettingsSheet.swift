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
    @State private var showResetConfirm: Bool = false
    @State private var showShuffleSuccess: Bool = false
    @State private var shuffleSpin: Bool = false

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

            // Inline TTS settings（取代舊的入口按鈕）
            DSOutlineCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
                    Text("tts.title").dsType(DS.Font.section)
                    VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                        Text("tts.order").dsType(DS.Font.caption).foregroundStyle(.secondary)
                        let s = ttsStore.settings
                        Picker("tts.order", selection: Binding(get: { s.readOrder }, set: { ttsStore.settings.readOrder = $0 })) {
                            Text(ReadOrder.frontOnly.displayName).tag(ReadOrder.frontOnly)
                            Text(ReadOrder.backOnly.displayName).tag(ReadOrder.backOnly)
                            Text(ReadOrder.frontThenBack.displayName).tag(ReadOrder.frontThenBack)
                            Text(ReadOrder.backThenFront.displayName).tag(ReadOrder.backThenFront)
                        }
                        .pickerStyle(.segmented)
                        .tint(DS.Palette.primary)
                    }

                    HStack(spacing: DS.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                            HStack { Text("tts.rate").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.2fx", ttsStore.settings.rate)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                            Slider(value: Binding(get: { Double(ttsStore.settings.rate) }, set: { ttsStore.settings.rate = Float($0) }), in: 0.3...0.6)
                                .tint(DS.Palette.primary)
                        }
                    }

                    HStack(spacing: DS.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                            HStack { Text("tts.segmentGap").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1fs", ttsStore.settings.segmentGap)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                            Slider(value: Binding(get: { ttsStore.settings.segmentGap }, set: { ttsStore.settings.segmentGap = $0 }), in: 0...2, step: 0.1)
                                .tint(DS.Palette.primary)
                        }
                        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                            HStack { Text("tts.cardGap").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1fs", ttsStore.settings.cardGap)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                            Slider(value: Binding(get: { ttsStore.settings.cardGap }, set: { ttsStore.settings.cardGap = $0 }), in: 0...3, step: 0.1)
                                .tint(DS.Palette.primary)
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                        Text("tts.variantFill").dsType(DS.Font.caption).foregroundStyle(.secondary)
                        Picker("tts.variantFill", selection: Binding(get: { ttsStore.settings.variantFill }, set: { ttsStore.settings.variantFill = $0 })) {
                            Text(VariantFill.random.displayName).tag(VariantFill.random)
                            Text(VariantFill.wrap.displayName).tag(VariantFill.wrap)
                        }
                        .pickerStyle(.segmented)
                        .tint(DS.Palette.primary)
                    }
                }
            }

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
                Button(String(localized: "action.done", locale: locale)) { dismiss() }
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

import SwiftUI

struct FlashcardsSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("flashcards.reviewMode") private var modeRaw: String = FlashcardsReviewMode.browse.storageValue
    @Environment(\.locale) private var locale
    @ObservedObject var ttsStore: TTSSettingsStore
    var onOpenAudio: (() -> Void)? = nil

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("nav.settings").dsType(DS.Font.section)
            VStack(alignment: .leading, spacing: 8) {
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
                VStack(alignment: .leading, spacing: 12) {
                    Text("tts.title").dsType(DS.Font.section)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("tts.order").dsType(DS.Font.caption).foregroundStyle(.secondary)
                        let s = ttsStore.settings
                        Picker("tts.order", selection: Binding(get: { s.readOrder }, set: { ttsStore.settings.readOrder = $0 })) {
                            Text("tts.order.front").tag(ReadOrder.frontOnly)
                            Text("tts.order.back").tag(ReadOrder.backOnly)
                            Text("tts.order.frontThenBack").tag(ReadOrder.frontThenBack)
                            Text("tts.order.backThenFront").tag(ReadOrder.backThenFront)
                        }
                        .pickerStyle(.segmented)
                        .tint(DS.Palette.primary)
                    }

                    HStack(spacing: DS.Spacing.lg) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("tts.rate").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.2fx", ttsStore.settings.rate)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                            Slider(value: Binding(get: { Double(ttsStore.settings.rate) }, set: { ttsStore.settings.rate = Float($0) }), in: 0.3...0.6)
                                .tint(DS.Palette.primary)
                        }
                    }

                    HStack(spacing: DS.Spacing.lg) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("tts.segmentGap").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1fs", ttsStore.settings.segmentGap)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                            Slider(value: Binding(get: { ttsStore.settings.segmentGap }, set: { ttsStore.settings.segmentGap = $0 }), in: 0...2, step: 0.1)
                                .tint(DS.Palette.primary)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("tts.cardGap").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1fs", ttsStore.settings.cardGap)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                            Slider(value: Binding(get: { ttsStore.settings.cardGap }, set: { ttsStore.settings.cardGap = $0 }), in: 0...3, step: 0.1)
                                .tint(DS.Palette.primary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("tts.variantFill").dsType(DS.Font.caption).foregroundStyle(.secondary)
                        Picker("tts.variantFill", selection: Binding(get: { ttsStore.settings.variantFill }, set: { ttsStore.settings.variantFill = $0 })) {
                            Text("tts.fill.random").tag(VariantFill.random)
                            Text("tts.fill.wrap").tag(VariantFill.wrap)
                        }
                        .pickerStyle(.segmented)
                        .tint(DS.Palette.primary)
                    }
                }
            }
            HStack { Spacer()
                Button(String(localized: "action.done", locale: locale)) { dismiss() }
                    .buttonStyle(DSSecondaryButton())
                    .frame(width: 100)
            }
        }
        .padding(16)
        }
        .background(DS.Palette.background)
    }

    private var helpText: String {
        if FlashcardsReviewMode.fromStorage(modeRaw) == .annotate {
            return String(localized: "flashcards.settings.help.annotate", locale: locale)
        } else {
            return String(localized: "flashcards.settings.help.browse", locale: locale)
        }
    }
}

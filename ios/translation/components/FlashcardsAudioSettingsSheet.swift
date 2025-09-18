import SwiftUI

struct FlashcardsAudioSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TTSSettingsStore
    var onStart: (TTSSettings) -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        let s = store.settings
        ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            DSSectionHeader(title: String(localized: "tts.title", locale: locale), subtitle: summaryText(), accentUnderline: true)

            DSOutlineCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("tts.order").dsType(DS.Font.caption).foregroundStyle(.secondary)
                    Picker("tts.order", selection: Binding(get: { s.readOrder }, set: { store.settings.readOrder = $0 })) {
                        Text("tts.order.front").tag(ReadOrder.frontOnly)
                        Text("tts.order.back").tag(ReadOrder.backOnly)
                        Text("tts.order.frontThenBack").tag(ReadOrder.frontThenBack)
                        Text("tts.order.backThenFront").tag(ReadOrder.backThenFront)
                    }
                    .tint(DS.Palette.primary)
                    .pickerStyle(.segmented)
                }
            }

            HStack(spacing: DS.Spacing.lg) {
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("tts.rate").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.2fx", store.settings.rate)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                        Slider(value: Binding(get: { Double(store.settings.rate) }, set: { store.settings.rate = Float($0) }), in: 0.3...0.6)
                            .tint(DS.Palette.primary)
                    }
                }
            }

            HStack(spacing: DS.Spacing.lg) {
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("tts.segmentGap").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1fs", store.settings.segmentGap)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                        Slider(value: Binding(get: { store.settings.segmentGap }, set: { store.settings.segmentGap = $0 }), in: 0...2, step: 0.1)
                            .tint(DS.Palette.primary)
                    }
                }
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("tts.cardGap").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1fs", store.settings.cardGap)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                        Slider(value: Binding(get: { store.settings.cardGap }, set: { store.settings.cardGap = $0 }), in: 0...3, step: 0.1)
                            .tint(DS.Palette.primary)
                    }
                }
            }

            DSOutlineCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("tts.variantFill").dsType(DS.Font.caption).foregroundStyle(.secondary)
                    Picker("tts.variantFill", selection: Binding(get: { store.settings.variantFill }, set: { store.settings.variantFill = $0 })) {
                        Text("tts.fill.random").tag(VariantFill.random)
                        Text("tts.fill.wrap").tag(VariantFill.wrap)
                    }
                    .tint(DS.Palette.primary)
                    .pickerStyle(.segmented)
                }
            }

            HStack {
                Spacer()
                Button(String(localized: "tts.start", locale: locale)) {
                    onStart(store.settings)
                    dismiss()
                }
                .buttonStyle(DSPrimaryButton())
                .frame(width: 160)
            }
        }
        .padding(16)
        .padding(.top, 8) // avoid top rounding clipping under sheet grabber
        }
        .background(DS.Palette.background)
        .presentationDragIndicator(.visible)
    }

    private func summaryText() -> String {
        let s = store.settings
        let order: String = s.readOrder == .frontOnly ? String(localized: "tts.order.front", locale: locale) : s.readOrder == .backOnly ? String(localized: "tts.order.back", locale: locale) : (s.readOrder == .frontThenBack ? String(localized: "tts.order.frontThenBack", locale: locale) : String(localized: "tts.order.backThenFront", locale: locale))
        let fill: String = s.variantFill == .random ? String(localized: "tts.fill.random", locale: locale) : String(localized: "tts.fill.wrap", locale: locale)
        return "\(order) • \(String(format: "%.2fx", s.rate)) • \(String(localized: "tts.segment.short", locale: locale)) \(String(format: "%.1fs", s.segmentGap)) • \(String(localized: "tts.card.short", locale: locale)) \(String(format: "%.1fs", s.cardGap)) • \(fill)"
    }
}

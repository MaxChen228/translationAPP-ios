import SwiftUI

struct FlashcardsAudioSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TTSSettingsStore
    var onStart: (TTSSettings) -> Void

    var body: some View {
        let s = store.settings
        ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            DSSectionHeader(title: "播音設定", subtitle: summaryText(), accentUnderline: true)

            DSOutlineCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("順序").dsType(DS.Font.caption).foregroundStyle(.secondary)
                    Picker("順序", selection: Binding(get: { s.readOrder }, set: { store.settings.readOrder = $0 })) {
                        Text("Front").tag(ReadOrder.frontOnly)
                        Text("Back").tag(ReadOrder.backOnly)
                        Text("Front→Back").tag(ReadOrder.frontThenBack)
                        Text("Back→Front").tag(ReadOrder.backThenFront)
                    }
                    .tint(DS.Palette.primary)
                    .pickerStyle(.segmented)
                }
            }

            HStack(spacing: DS.Spacing.lg) {
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("語速").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.2fx", store.settings.rate)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                        Slider(value: Binding(get: { Double(store.settings.rate) }, set: { store.settings.rate = Float($0) }), in: 0.3...0.6)
                            .tint(DS.Palette.primary)
                    }
                }
            }

            HStack(spacing: DS.Spacing.lg) {
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("段間隔").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1fs", store.settings.segmentGap)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                        Slider(value: Binding(get: { store.settings.segmentGap }, set: { store.settings.segmentGap = $0 }), in: 0...2, step: 0.1)
                            .tint(DS.Palette.primary)
                    }
                }
                DSOutlineCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("卡間隔").dsType(DS.Font.caption).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1fs", store.settings.cardGap)).dsType(DS.Font.caption).foregroundStyle(.secondary) }
                        Slider(value: Binding(get: { store.settings.cardGap }, set: { store.settings.cardGap = $0 }), in: 0...3, step: 0.1)
                            .tint(DS.Palette.primary)
                    }
                }
            }

            DSOutlineCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("變體補位").dsType(DS.Font.caption).foregroundStyle(.secondary)
                    Picker("補位", selection: Binding(get: { store.settings.variantFill }, set: { store.settings.variantFill = $0 })) {
                        Text("隨機").tag(VariantFill.random)
                        Text("循環").tag(VariantFill.wrap)
                    }
                    .tint(DS.Palette.primary)
                    .pickerStyle(.segmented)
                }
            }

            HStack {
                Spacer()
                Button("開始播放") {
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
        let order: String = s.readOrder == .frontOnly ? "Front" : s.readOrder == .backOnly ? "Back" : (s.readOrder == .frontThenBack ? "Front→Back" : "Back→Front")
        let fill: String = s.variantFill == .random ? "隨機" : "循環"
        return "\(order) • \(String(format: "%.2fx", s.rate)) • 段 \(String(format: "%.1fs", s.segmentGap)) • 卡 \(String(format: "%.1fs", s.cardGap)) • \(fill)"
    }
}

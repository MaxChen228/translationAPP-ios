import SwiftUI

struct FlashcardsAudioSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TTSSettingsStore
    var onStart: (TTSSettings) -> Void

    var body: some View {
        let s = store.settings
        VStack(alignment: .leading, spacing: 14) {
            Text("播音設定").dsType(DS.Font.section)

            // Read order
            VStack(alignment: .leading, spacing: 8) {
                Text("順序").dsType(DS.Font.caption).foregroundStyle(.secondary)
                Picker("順序", selection: Binding(get: { s.readOrder }, set: { store.settings.readOrder = $0 })) {
                    Text("Front").tag(ReadOrder.frontOnly)
                    Text("Back").tag(ReadOrder.backOnly)
                    Text("Front→Back").tag(ReadOrder.frontThenBack)
                    Text("Back→Front").tag(ReadOrder.backThenFront)
                }.pickerStyle(.segmented)
            }

            // Rate
            VStack(alignment: .leading, spacing: 8) {
                Text("語速").dsType(DS.Font.caption).foregroundStyle(.secondary)
                Slider(value: Binding(get: { Double(store.settings.rate) }, set: { store.settings.rate = Float($0) }), in: 0.3...0.6)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("段間隔").dsType(DS.Font.caption).foregroundStyle(.secondary)
                    Slider(value: Binding(get: { store.settings.segmentGap }, set: { store.settings.segmentGap = $0 }), in: 0...2, step: 0.1)
                }
                VStack(alignment: .leading) {
                    Text("卡間隔").dsType(DS.Font.caption).foregroundStyle(.secondary)
                    Slider(value: Binding(get: { store.settings.cardGap }, set: { store.settings.cardGap = $0 }), in: 0...3, step: 0.1)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("變體補位").dsType(DS.Font.caption).foregroundStyle(.secondary)
                Picker("補位", selection: Binding(get: { store.settings.variantFill }, set: { store.settings.variantFill = $0 })) {
                    Text("隨機").tag(VariantFill.random)
                    Text("循環").tag(VariantFill.wrap)
                }.pickerStyle(.segmented)
            }

            HStack {
                Spacer()
                Button("開始播放") {
                    onStart(store.settings)
                    dismiss()
                }
                .buttonStyle(DSPrimaryButton())
                .frame(width: 140)
            }
        }
        .padding(16)
        .background(DS.Palette.background)
    }
}


import SwiftUI

struct FlashcardsSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("flashcards.reviewMode") private var modeRaw: String = FlashcardsReviewMode.browse.rawValue
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("nav.settings").dsType(DS.Font.section)
            VStack(alignment: .leading, spacing: 8) {
                Text("flashcards.settings.mode").dsType(DS.Font.caption).foregroundStyle(.secondary)
                Picker("複習模式", selection: $modeRaw) {
                    ForEach(FlashcardsReviewMode.allCases, id: \.rawValue) { m in
                        Text(m.rawValue).tag(m.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Text(helpText).dsType(DS.Font.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button(String(localized: "action.done", locale: locale)) { dismiss() }
                    .buttonStyle(DSPrimaryButton())
                    .frame(width: 120)
            }
        }
        .padding(16)
        .background(DS.Palette.background)
    }

    private var helpText: String {
        if modeRaw == FlashcardsReviewMode.annotate.rawValue {
            return String(localized: "flashcards.settings.help.annotate", locale: locale)
        } else {
            return String(localized: "flashcards.settings.help.browse", locale: locale)
        }
    }
}

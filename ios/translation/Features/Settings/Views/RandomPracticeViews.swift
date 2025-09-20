import SwiftUI

struct RandomPracticeToolbarButton: View {
    var action: () -> Void
    var body: some View {
        DSQuickActionIconButton(systemName: "die.face.5", labelKey: "bank.random.title", action: action)
    }
}

struct RandomSettingsToolbarButton: View {
    var onOpen: () -> Void
    var body: some View {
        DSQuickActionIconButton(systemName: "gearshape", labelKey: "bank.random.settings", action: onOpen)
    }
}

struct RandomPracticeSettingsSheet: View {
    @EnvironmentObject private var settings: RandomPracticeStore
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            DSSectionHeader(titleKey: "bank.random.settings", accentUnderline: true)
            DSOutlineCard {
                Toggle(isOn: $settings.excludeCompleted) {
                    Text("bank.random.excludeCompleted")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
        .background(DS.Palette.background)
    }
}

import SwiftUI

struct TypingIndicator: View {
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(DS.Palette.primary)
            Text("chat.state.gathering")
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DS.Spacing.sm2)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.border.opacity(DS.Opacity.hairline), lineWidth: DS.BorderWidth.hairline)
        )
        .frame(maxWidth: 240, alignment: .leading)
    }
}

struct ChatStateBadge: View {
    var state: ChatTurnResponse.State
    var isLoading: Bool

    private var displayState: ChatTurnResponse.State { isLoading ? .gathering : state }

    var body: some View {
        let color = tint(for: displayState)
        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title(for: displayState))
                .dsType(DS.Font.caption)
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.12))
        )
    }

    private func title(for state: ChatTurnResponse.State) -> LocalizedStringKey {
        switch state {
        case .gathering: return "chat.state.gathering"
        case .ready: return "chat.state.ready"
        case .completed: return "chat.state.completed"
        }
    }

    private func tint(for state: ChatTurnResponse.State) -> Color {
        switch state {
        case .gathering: return DS.Brand.scheme.babyBlue
        case .ready: return DS.Brand.scheme.classicBlue
        case .completed: return DS.Palette.success
        }
    }
}

struct ErrorBanner: View {
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DS.Palette.warning)
            Text(verbatim: text)
                .dsType(DS.Font.body, lineSpacing: 4)
                .foregroundStyle(DS.Palette.warning)
        }
        .padding(.vertical, DS.Spacing.sm2)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.warning.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Palette.warning.opacity(0.5), lineWidth: DS.BorderWidth.hairline)
        )
    }
}

struct ContinuationBanner: View {
    var onResume: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(DS.Brand.scheme.classicBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text("chat.continuation.title")
                    .dsType(DS.Font.body)
                    .foregroundStyle(.primary)
                Text("chat.continuation.subtitle")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onResume) {
                Text("chat.continuation.resume")
            }
            .buttonStyle(DSButton(style: .secondary, size: .compact))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.sm2)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Brand.scheme.babyBlue.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Brand.scheme.classicBlue.opacity(0.3), lineWidth: DS.BorderWidth.hairline)
        )
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.sm)
    }
}

struct BackgroundTaskIndicator: View {
    var body: some View {
        HStack(spacing: DS.Spacing.sm2) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(DS.Brand.scheme.classicBlue)
                .scaleEffect(0.8)

            Text("chat.background.active")
                .dsType(DS.Font.caption)
                .foregroundStyle(DS.Brand.scheme.classicBlue)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, DS.Spacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(DS.Brand.scheme.babyBlue.opacity(0.12))
        )
        .padding(.horizontal, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm2)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
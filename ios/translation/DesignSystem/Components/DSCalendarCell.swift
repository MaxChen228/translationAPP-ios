import SwiftUI

struct DSCalendarCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let onTap: () -> Void

    private var cellSize: CGFloat { 40 }

    private var textColor: Color {
        if !day.isCurrentMonth {
            return DS.Palette.subdued.opacity(0.4)
        }
        if day.isToday {
            return DS.Palette.onPrimary
        }
        if isSelected {
            return DS.Palette.onPrimary
        }
        return DS.Palette.primary
    }

    private var backgroundColor: Color {
        if day.isToday {
            return DS.Palette.primary
        }
        if isSelected {
            return DS.Palette.primary.opacity(0.8)
        }
        if day.hasActivity {
            return DS.Palette.primary.opacity(DS.Opacity.fill)
        }
        return Color.clear
    }

    private var borderColor: Color? {
        if day.hasActivity && !day.isToday && !isSelected {
            return DS.Palette.primary.opacity(DS.Opacity.border)
        }
        return nil
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .overlay(
                        Group {
                            if let borderColor {
                                Circle()
                                    .stroke(borderColor, lineWidth: DS.BorderWidth.regular)
                            }
                        }
                    )

                VStack(spacing: 2) {
                    Text("\(day.dayNumber)")
                        .font(DS.Font.labelSm)
                        .fontWeight(day.isToday ? .semibold : .medium)
                        .foregroundStyle(textColor)

                    if day.hasActivity {
                        DSActivityIndicator(
                            count: day.practiceCount,
                            averageScore: day.averageScore
                        )
                    }
                }
            }
            .frame(width: cellSize, height: cellSize)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .dsAnimation(DS.AnimationToken.subtle, value: isSelected)
        .dsAnimation(DS.AnimationToken.subtle, value: day.hasActivity)
    }
}

private struct DSActivityIndicator: View {
    let count: Int
    let averageScore: Double?

    private var indicatorColor: Color {
        guard let score = averageScore else {
            return DS.Palette.neutral
        }

        switch score {
        case 90...: return DS.Palette.success
        case 70..<90: return DS.Palette.warning
        case 50..<70: return DS.Palette.caution
        default: return DS.Palette.danger
        }
    }

    private var indicatorSize: CGFloat {
        switch count {
        case 1: return 4
        case 2...5: return 5
        case 6...10: return 6
        default: return 7
        }
    }

    var body: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: indicatorSize, height: indicatorSize)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
    }
}
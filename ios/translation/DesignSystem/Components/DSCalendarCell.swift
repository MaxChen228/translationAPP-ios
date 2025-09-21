import SwiftUI

struct DSCalendarCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let onTap: () -> Void

    private var cellSize: CGFloat { DS.IconSize.calendarCell }

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
            VStack(spacing: DS.Spacing.xs) {
                Text("\(day.dayNumber)")
                    .dsType(DS.Font.labelSm)
                    .fontWeight(day.isToday ? .semibold : .medium)
                    .foregroundStyle(textColor)

                if day.hasActivity {
                    DSCalendarActivityIndicator(
                        count: day.practiceCount,
                        averageScore: day.averageScore
                    )
                }
            }
        }
        .buttonStyle(DSCalendarCellStyle(
            isSelected: isSelected,
            backgroundColor: backgroundColor,
            borderColor: borderColor
        ))
        .contentShape(Circle())
    }
}

private struct DSCalendarActivityIndicator: View {
    let count: Int
    let averageScore: Double?

    private var indicatorColor: Color {
        guard let score = averageScore else {
            return DS.Palette.neutral
        }
        return DS.Palette.scoreColor(for: score)
    }

    private var indicatorSize: CGFloat {
        DS.CalendarMetrics.activityIndicatorSize(for: count)
    }

    var body: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: indicatorSize, height: indicatorSize)
            .overlay(
                Circle()
                    .stroke(DS.Palette.onPrimary.opacity(DS.Opacity.hairline), lineWidth: DS.BorderWidth.hairline)
            )
    }
}
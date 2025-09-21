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
            return DS.Palette.primary
        }
        if isSelected {
            return DS.Palette.primary
        }
        return DS.Palette.primary
    }

    private var backgroundColor: Color {
        return Color.clear
    }

    private var borderColor: Color? {
        if day.isToday {
            return DS.Palette.primary
        }
        if isSelected {
            return DS.Palette.primary
        }
        if day.hasActivity {
            return DS.Palette.primary.opacity(DS.Opacity.border)
        }
        return nil
    }

    private var borderWidth: CGFloat {
        if day.isToday {
            return DS.BorderWidth.regular
        }
        if isSelected {
            return DS.BorderWidth.regular * 1.5
        }
        if day.hasActivity {
            return DS.BorderWidth.hairline
        }
        return 0
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.xs) {
                Text("\(day.dayNumber)")
                    .dsType(day.isToday ? DS.Font.serifBody : DS.Font.labelSm)
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
            borderColor: borderColor,
            borderWidth: borderWidth
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
            .stroke(indicatorColor, lineWidth: DS.BorderWidth.thin)
            .frame(width: indicatorSize, height: indicatorSize)
    }
}
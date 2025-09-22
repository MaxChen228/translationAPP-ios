import SwiftUI

struct DayDetailView: View {
    let stats: DayPracticeStats

    var body: some View {
        DSOutlineCard(padding: DS.Spacing.lg, fill: DS.Palette.surfaceAlt.opacity(0.4)) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection

                DSSeparator(color: DS.Palette.border.opacity(DS.Opacity.hairline))

                statsGrid

                if stats.count > 1 {
                    DSSeparator(color: DS.Palette.border.opacity(DS.Opacity.hairline))
                    practiceTimeInfo
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            DSCardTitle(
                icon: "calendar",
                titleText: formattedDate,
                showChevron: false
            )

            Spacer()

            AnimatedStreakBadge(streakDays: stats.streakDays)
        }
    }

    private var statsGrid: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            metricColumn(
                label: "練習題數",
                value: "\(stats.count)"
            )

            metricColumn(
                label: "錯誤總數",
                value: "\(stats.totalErrors)"
            )

            metricColumn(
                label: "最高分",
                value: "\(stats.bestScore)"
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func metricColumn(label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(DS.Palette.primary)

            Text(label)
                .dsType(DS.Font.caption)
                .foregroundStyle(DS.Palette.subdued)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.background.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.hairline)
        )
    }

    private var practiceTimeInfo: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "clock")
                .dsType(DS.Font.caption)
                .foregroundStyle(DS.Palette.subdued)

            Text("總練習時間：\(formattedPracticeTime)")
                .dsType(DS.Font.caption)
                .foregroundStyle(DS.Palette.subdued)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M.d"
        return formatter.string(from: stats.date)
    }

    private var formattedPracticeTime: String {
        let minutes = Int(stats.practiceTime / 60)
        if minutes < 60 {
            return "\(minutes) 分鐘"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours) 小時 \(remainingMinutes) 分鐘"
        }
    }
}

private struct AnimatedStreakBadge: View {
    let streakDays: Int

    @State private var breathing = false
    @State private var animateGradient = false

    private let gradientColors: [Color] = [
        DS.Brand.scheme.cornhusk,
        DS.Brand.scheme.peachQuartz,
        DS.Brand.scheme.provence,
        DS.Brand.scheme.classicBlue
    ]

    private let badgeSize: CGFloat = 88
    private let outerLineWidth: CGFloat = DS.BorderWidth.emphatic
    private let innerLineWidth: CGFloat = DS.BorderWidth.hairline
    private let innerInset: CGFloat = 8
    private let fillInset: CGFloat = 16
    private let gradientDuration: Double = 8.0

    private var gradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: gradientColors[0], location: 0.0),
                .init(color: gradientColors[1], location: 0.33),
                .init(color: gradientColors[2], location: 0.66),
                .init(color: gradientColors[3], location: 1.0)
            ]),
            center: .center
        )
    }

    var body: some View {
        ZStack {
            gradientCircle(lineWidth: outerLineWidth)
                .frame(width: badgeSize, height: badgeSize)
                .rotationEffect(.degrees(animateGradient ? 360 : 0))
                .animation(.linear(duration: gradientDuration).repeatForever(autoreverses: false), value: animateGradient)

            gradientCircle(lineWidth: innerLineWidth)
                .frame(width: badgeSize - innerInset * 2, height: badgeSize - innerInset * 2)
                .rotationEffect(.degrees(animateGradient ? -360 : 0))
                .animation(.linear(duration: gradientDuration * 1.2).repeatForever(autoreverses: false), value: animateGradient)

            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: badgeSize - fillInset, height: badgeSize - fillInset)
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .blur(radius: 8)
                        .frame(width: badgeSize - fillInset - 10, height: badgeSize - fillInset - 10)
                )

            badgeContent
        }
        .frame(width: badgeSize, height: badgeSize)
        .scaleEffect(breathing ? 1.05 : 1.0)
        .shadow(color: DS.Palette.primary.opacity(breathing ? 0.28 : 0.16), radius: breathing ? 18 : 12, y: 8)
        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: breathing)
        .onAppear {
            breathing = true
            animateGradient = true
        }
        .onDisappear {
            breathing = false
            animateGradient = false
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("連續 \(streakDays) 天")
    }

    private func gradientCircle(lineWidth: CGFloat) -> some View {
        Circle()
            .strokeBorder(gradient, lineWidth: lineWidth)
    }

    private var badgeContent: some View {
        VStack(spacing: 6) {
            GradientText(text: "連續", gradient: gradient)
                .font(DS.Font.body)
                .fontWeight(.semibold)

            VStack(spacing: 1) {
                Text("\(streakDays)")
                    .font(DS.Font.scriptTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: streakDays)

                GradientText(text: "天", gradient: gradient)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
            }
        }
    }
}

private struct GradientText: View {
    let text: String
    let gradient: AngularGradient

    var body: some View {
        Text(text)
            .foregroundStyle(gradient)
    }
}

import SwiftUI

struct DayDetailView: View {
    let stats: DayPracticeStats

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var metricsPreferences: CalendarMetricsPreferencesStore

    @StateObject private var metricsEditController = ShelfEditController<CalendarMetric>()
    @State private var showMetricPicker = false

    private var monthDay: (month: String, day: String) {
        CalendarFormatting.monthAndDay(stats.date, locale: locale, calendar: calendar)
    }

    private var visibleMetrics: [CalendarMetric] {
        metricsPreferences.visibleMetrics
    }

    private var availableMetrics: [CalendarMetric] {
        CalendarMetric.allCases.filter { !metricsPreferences.isVisible($0) }
    }

    var body: some View {
        DSOutlineCard(padding: DS.Spacing.lg, fill: DS.Palette.surfaceAlt.opacity(0.25)) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection

                DSSeparator(color: DS.Palette.border.opacity(DS.Opacity.hairline))

                metricsSection

                if metricsEditController.isEditing {
                    metricsEditorFooter
                }
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: visibleMetrics)
        .sheet(isPresented: $showMetricPicker) {
            CalendarMetricPicker(
                availableMetrics: availableMetrics,
                onSelect: handleMetricSelection,
                onClose: { showMetricPicker = false }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var headerSection: some View {
        let components = monthDay

        return HStack(alignment: .center, spacing: DS.Spacing.lg) {
            HStack(alignment: .bottom, spacing: DS.Spacing.xs2) {
                Text(components.month)
                    .font(.custom(
                        DS.FontFamily.tangerineCandidates.first ?? "Tangerine-Bold",
                        size: 60
                    ))
                    .kerning(1.4)

                Text("/")
                    .font(.custom(
                        DS.FontFamily.tangerineCandidates.first ?? "Tangerine-Regular",
                        size: 42
                    ))
                    .baselineOffset(8)

                Text(components.day)
                    .font(.custom(
                        DS.FontFamily.tangerineCandidates.first ?? "Tangerine-Regular",
                        size: 40
                    ))
                    .kerning(1.0)
            }

            Spacer(minLength: DS.Spacing.md)

            AnimatedStreakBadge(streakDays: stats.streakDays)
        }
    }

    private var metricsSection: some View {
        let metrics = visibleMetrics
        let columns = gridColumns(for: metrics.count)

        return LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            ForEach(Array(metrics.enumerated()), id: \.element) { index, metric in
                metricTile(for: metric)
                    .gridCellColumns(gridSpan(for: metrics.count, index: index))
            }

            if metricsEditController.isEditing,
               metrics.count < CalendarMetric.maxVisibleCount,
               !availableMetrics.isEmpty {
                addMetricTile
                    .gridCellColumns(addTileSpan(for: metrics.count))
                    .onDrop(of: [.text], delegate: CalendarMetricAppendDropDelegate(
                        preferences: metricsPreferences,
                        editController: metricsEditController
                    ))
            }
        }
        .onDrop(of: [.text], delegate: CalendarMetricClearDragDropDelegate(editController: metricsEditController))
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.4) {
            guard !metricsEditController.isEditing else { return }
            Haptics.medium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                metricsEditController.enterEditMode()
            }
        }
    }

    private func metricTile(for metric: CalendarMetric) -> some View {
        let value = metric.value(for: stats, locale: locale, calendar: calendar)
        let isEditing = metricsEditController.isEditing

        return VStack(spacing: DS.Spacing.xs) {
            Image(systemName: metric.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.Palette.subdued)

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(DS.Palette.primary)
                .minimumScaleFactor(0.7)

            Text(metric.title)
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
        .shelfSelectable(isEditing: isEditing, isSelected: true)
        .shelfWiggle(isActive: isEditing)
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .onTapGesture {
            guard isEditing else { return }
            if visibleMetrics.count > 1 {
                Haptics.selection()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    metricsPreferences.remove(metric)
                }
            } else {
                Haptics.warning()
            }
        }
        .shelfConditionalDrag(isEditing) {
            metricsEditController.beginDragging(metric)
            let payload = ShelfDragPayload(
                primaryID: metric.rawValue,
                selectedIDs: [metric.rawValue]
            )
            return NSItemProvider(object: payload.encodedString() as NSString)
        }
        .onDrop(of: [.text], delegate: CalendarMetricReorderDropDelegate(
            target: metric,
            preferences: metricsPreferences,
            editController: metricsEditController
        ))
    }

    private var addMetricTile: some View {
        Button {
            Haptics.selection()
            showMetricPicker = true
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DS.Palette.primary)
                Text("新增項目")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(DS.Palette.subdued)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(DS.Palette.primary.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.hairline)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(DS.Palette.background.opacity(0.15))
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var metricsEditorFooter: some View {
        DSFooterActionBar {
            Button {
                Haptics.selection()
                metricsPreferences.reset()
            } label: {
                Text("恢復預設")
            }
            .buttonStyle(DSButton(style: .secondary, size: .full))

            Button {
                Haptics.success()
                finishEditing()
            } label: {
                Text("完成")
            }
            .buttonStyle(DSButton(style: .primary, size: .full))
        }
    }

    private func finishEditing() {
        showMetricPicker = false
        metricsEditController.exitEditMode()
    }

    private func handleMetricSelection(_ metric: CalendarMetric) {
        guard availableMetrics.contains(metric) else { return }
        Haptics.selection()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            metricsPreferences.append(metric)
        }
    }

    private func gridColumns(for count: Int) -> [GridItem] {
        if count <= 1 {
            return [GridItem(.flexible(), spacing: DS.Spacing.md)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.md), count: 2)
    }

    private func gridSpan(for total: Int, index: Int) -> Int {
        if total <= 1 { return 1 }
        if total == 3 && index == 2 { return 2 }
        return 1
    }

    private func addTileSpan(for total: Int) -> Int {
        if total <= 1 { return 1 }
        if total == 3 { return 2 }
        return 1
    }
}

private struct CalendarMetricReorderDropDelegate: DropDelegate {
    let target: CalendarMetric
    unowned let preferences: CalendarMetricsPreferencesStore
    unowned let editController: ShelfEditController<CalendarMetric>

    func validateDrop(info: DropInfo) -> Bool { editController.isEditing }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard editController.isEditing,
              let dragging = editController.draggingID,
              dragging != target else { return }
        preferences.move(metric: dragging, before: target)
        Haptics.lightTick()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard editController.isEditing else { return false }
        editController.endDragging()
        Haptics.success()
        return true
    }
}

private struct CalendarMetricAppendDropDelegate: DropDelegate {
    unowned let preferences: CalendarMetricsPreferencesStore
    unowned let editController: ShelfEditController<CalendarMetric>

    func validateDrop(info: DropInfo) -> Bool { editController.isEditing }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        guard editController.isEditing,
              let dragging = editController.draggingID else { return false }
        preferences.moveToEnd(dragging)
        editController.endDragging()
        Haptics.success()
        return true
    }
}

private struct CalendarMetricClearDragDropDelegate: DropDelegate {
    unowned let editController: ShelfEditController<CalendarMetric>

    func validateDrop(info: DropInfo) -> Bool { editController.isEditing }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        guard editController.isEditing else { return false }
        editController.endDragging()
        return true
    }
}

private struct CalendarMetricPicker: View {
    let availableMetrics: [CalendarMetric]
    let onSelect: (CalendarMetric) -> Void
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.sm) {
                    if availableMetrics.isEmpty {
                        DSCard {
                            Text("已選滿所有可用項目")
                                .dsType(DS.Font.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(availableMetrics) { metric in
                            Button {
                                onSelect(metric)
                                dismissSheet()
                            } label: {
                                HStack(spacing: DS.Spacing.md) {
                                    Image(systemName: metric.systemImage)
                                        .foregroundStyle(DS.Palette.primary)
                                    Text(metric.title)
                                        .dsType(DS.Font.body)
                                        .foregroundStyle(DS.Palette.subdued)
                                    Spacer()
                                }
                                .padding(.vertical, DS.Spacing.sm2)
                                .padding(.horizontal, DS.Spacing.md)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                        .stroke(DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.hairline)
                                        .background(
                                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                                .fill(DS.Palette.background.opacity(0.1))
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
            }
            .navigationTitle("選擇顯示項目")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismissSheet()
                    }
                }
            }
        }
    }

    private func dismissSheet() {
        onClose()
        dismiss()
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
                .init(color: gradientColors[3], location: 0.99),
                .init(color: gradientColors[0], location: 1.0)
            ]),
            center: .center
        )
    }

    private var textGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: gradientColors[0], location: 0.0),
                .init(color: gradientColors[1], location: 0.3),
                .init(color: gradientColors[2], location: 0.65),
                .init(color: gradientColors[3], location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
                .fill(DS.Palette.onPrimary.opacity(DS.Opacity.badgeFill))
                .frame(width: badgeSize - fillInset, height: badgeSize - fillInset)
                .overlay(
                    Circle()
                        .fill(DS.Palette.onPrimary.opacity(DS.Opacity.highlightActive))
                        .blur(radius: DS.Component.CalendarBadge.glowBlur)
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
        GeometryReader { geo in
            Text("\(streakDays)")
                .font(.system(size: geo.size.width * 0.62, weight: .semibold, design: .serif))
                .foregroundStyle(textGradient)
                .shadow(color: DS.Palette.onPrimary.opacity(DS.Opacity.highlightActive), radius: 4, y: 1)
                .frame(width: geo.size.width, height: geo.size.height)
                .minimumScaleFactor(0.65)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: streakDays)
        }
    }
}

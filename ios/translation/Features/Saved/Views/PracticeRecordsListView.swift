import SwiftUI

struct PracticeRecordsListView: View {
    @StateObject private var viewModel: PracticeRecordsListViewModel
    @Environment(\.locale) private var locale
    private let calendar: Calendar

    private enum DeleteContext {
        case single(PracticeRecord)
        case clearAll

        var titleKey: LocalizedStringKey {
            switch self {
            case .single:
                return "practice.records.delete.confirm.title"
            case .clearAll:
                return "practice.records.clear.confirm.title"
            }
        }

        var messageKey: LocalizedStringKey {
            switch self {
            case .single:
                return "practice.records.delete.confirm.message"
            case .clearAll:
                return "practice.records.clear.confirm.message"
            }
        }

        var actionLabelKey: LocalizedStringKey {
            switch self {
            case .single:
                return "practice.records.delete.confirm.action"
            case .clearAll:
                return "practice.records.clear.confirm.action"
            }
        }
    }

    @State private var showDeleteConfirmation = false
    @State private var deleteContext: DeleteContext?
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()

    init(store: PracticeRecordsStore, calendar: Calendar = .current) {
        _viewModel = StateObject(wrappedValue: PracticeRecordsListViewModel(store: store, calendar: calendar))
        self.calendar = calendar
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    filterSection

                    if viewModel.stats.totalRecords == 0 {
                        emptyState
                    } else {
                        statsSection
                        recordsList
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
            }
            .navigationTitle("practice.records.title")
            .toolbar {
                if viewModel.totalRecordsOverall > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("practice.records.clear.all") {
                            deleteContext = .clearAll
                            showDeleteConfirmation = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog(
                deleteContext?.titleKey ?? "practice.records.clear.confirm.title",
                isPresented: $showDeleteConfirmation
            ) {
                if let context = deleteContext {
                    Button(context.actionLabelKey, role: .destructive) {
                        handleDeleteConfirmation(for: context)
                    }
                }
                Button("cancel", role: .cancel) {
                    showDeleteConfirmation = false
                    deleteContext = nil
                }
            } message: {
                if let context = deleteContext {
                    Text(context.messageKey)
                }
            }
            .sheet(isPresented: $viewModel.isShowingCustomDateSheet) {
                customDateSheet
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("practice.records.filter.title")
                .dsType(DS.Font.caption)
                .foregroundStyle(.tertiary)

            Menu {
                let presets = PracticeRecordsDateFilter.presets
                ForEach(Array(presets.enumerated()), id: \.offset) { entry in
                    let option = entry.element
                    Button {
                        viewModel.filter = option
                    } label: {
                        HStack {
                            if viewModel.filter == option {
                                Image(systemName: "checkmark")
                            }
                            Text(option.title(locale: locale, calendar: calendar))
                        }
                    }
                }

                Divider()

                Button("practice.records.filter.custom.pick") {
                    prepareCustomRange()
                    viewModel.isShowingCustomDateSheet = true
                }

                if case .custom = viewModel.filter {
                    Button("practice.records.filter.clear", role: .destructive) {
                        viewModel.resetFilter()
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.filter.title(locale: locale, calendar: calendar))
                        .dsType(DS.Font.body)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: DS.IconSize.chevronSm, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    Capsule()
                        .fill(DS.Palette.surfaceAlt)
                )
            }
        }
    }

    private var emptyState: some View {
        Group {
            if viewModel.totalRecordsOverall == 0 {
                DSOutlineCard {
                    VStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("practice.records.empty.title")
                            .dsType(DS.Font.serifTitle)
                            .fontWeight(.semibold)
                        Text("practice.records.empty.subtitle")
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DS.Spacing.xl)
                }
            } else {
                DSOutlineCard {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("practice.records.empty.filtered")
                            .dsType(DS.Font.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DS.Spacing.xl)
                }
            }
        }
    }

    private var statsSection: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSSectionHeader(titleKey: "practice.records.stats.title", subtitleKey: "practice.records.stats.subtitle", accentUnderline: true)

                let stats = viewModel.stats
                HStack(spacing: DS.Spacing.xl) {
                    DSStatItem(
                        icon: "doc.text",
                        label: "總記錄",
                        value: "\(stats.totalRecords)"
                    )
                    DSStatItem(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "平均分數",
                        value: String(format: "%.1f", stats.averageScore)
                    )
                    DSStatItem(
                        icon: "exclamationmark.triangle",
                        label: "總錯誤數",
                        value: "\(stats.totalErrors)"
                    )
                }
                .padding(.top, DS.Spacing.xs)
            }
        }
    }

    private var recordsList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            DSSectionHeader(titleKey: "practice.records.list.title", subtitleKey: "practice.records.list.subtitle", accentUnderline: true)

            LazyVStack(spacing: DS.Spacing.md) {
                ForEach(viewModel.displayedRecords) { record in
                    PracticeRecordCard(record: record) {
                        deleteContext = .single(record)
                        showDeleteConfirmation = true
                    }
                    .onAppear {
                        viewModel.loadMoreIfNeeded(currentItem: record)
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                }
            }
        }
    }

    private func handleDeleteConfirmation(for context: DeleteContext) {
        switch context {
        case .single(let record):
            viewModel.delete(record)
        case .clearAll:
            viewModel.clearAll()
        }
        showDeleteConfirmation = false
        deleteContext = nil
    }

    private func prepareCustomRange() {
        if let interval = viewModel.selectedCustomRange {
            customStartDate = interval.start
            let endReference = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
            customEndDate = endReference
        } else {
            customEndDate = Date()
            customStartDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: customEndDate)) ?? customEndDate
        }
    }

    private var customDateSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("practice.records.filter.custom.start")) {
                    DatePicker("practice.records.filter.custom.start", selection: $customStartDate, displayedComponents: .date)
                }
                Section(header: Text("practice.records.filter.custom.end")) {
                    DatePicker("practice.records.filter.custom.end", selection: $customEndDate, displayedComponents: .date)
                }
            }
            .navigationTitle("practice.records.filter.custom.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        viewModel.isShowingCustomDateSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("practice.records.filter.custom.apply") {
                        let start = min(customStartDate, customEndDate)
                        let end = max(customStartDate, customEndDate)
                        viewModel.applyCustomRange(start: start, end: end)
                    }
                }
            }
        }
    }
}

#Preview {
    PracticeRecordsListView(store: PracticeRecordsStore())
}

import SwiftUI

struct CloudCourseLibraryView: View {
    @ObservedObject var vm: CorrectionViewModel
    @EnvironmentObject private var bannerCenter: BannerCenter
    private let service: CloudLibraryService = CloudLibraryServiceFactory.makeDefault()

    @State private var courses: [CloudCourseSummary] = []
    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    @Environment(\.locale) private var locale

    var body: some View {
        DSScrollContainer {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center)
                }
                if let error {
                    ErrorStateCard(title: error)
                }

                DSSectionHeader(titleKey: "cloud.courses.title", subtitleKey: "cloud.courses.subtitle", accentUnderline: true)

                if !isLoading && error == nil && courses.isEmpty {
                    EmptyStateCard(
                        title: String(localized: "cloud.courses.empty", locale: locale),
                        subtitle: String(localized: "cloud.common.retry", locale: locale),
                        iconSystemName: "rectangle.stack"
                    )
                }

                LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(courses) { course in
                        NavigationLink {
                            CloudCourseDetailView(vm: vm, course: course)
                        } label: {
                            CloudCourseSummaryCard(course: course)
                        }
                        .buttonStyle(DSCardLinkStyle())
                    }
                }
            }
        }
        .navigationTitle(Text("nav.cloudCourses"))
        .task { await loadCourses() }
        .refreshable { await loadCourses() }
    }

    private func loadCourses() async {
        if isLoading { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard AppConfig.backendURL != nil else {
            let msg = String(localized: "banner.backend.missing.subtitle", locale: locale)
            error = msg
            bannerCenter.show(title: String(localized: "banner.backend.missing.title", locale: locale), subtitle: msg)
            courses = []
            return
        }

        do {
            let fetched = try await service.fetchCourses()
            if Task.isCancelled { return }
            courses = fetched.sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        } catch {
            if isCancellationError(error) { return }
            self.error = (error as NSError).localizedDescription
            courses = []
            bannerCenter.show(title: String(localized: "banner.cloud.loadFailed.title", locale: locale), subtitle: self.error)
        }
    }
}

private struct CloudCourseSummaryCard: View {
    let course: CloudCourseSummary
    @Environment(\.locale) private var locale

    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if let urlString = course.coverImage, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Color.gray.opacity(0.12)
                        case .empty:
                            Color.gray.opacity(0.05)
                        @unknown default:
                            Color.gray.opacity(0.05)
                        }
                    }
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .stroke(DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.hairline)
                    )
                }

                VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
                    Text(course.title)
                        .dsType(DS.Font.section)
                    if let summary = course.summary, !summary.isEmpty {
                        Text(summary)
                            .dsType(DS.Font.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "books.vertical")
                        .foregroundStyle(DS.Palette.primary.opacity(0.6))
                    Text(String(format: String(localized: "cloud.course.bookCount", locale: locale), course.bookCount))
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)

                    if !course.tags.isEmpty {
                        Text(course.tags.joined(separator: " • "))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, DS.Spacing.sm)
        }
    }
}

import SwiftUI

struct CloudCourseDetailView: View {
    @ObservedObject var vm: CorrectionViewModel
    let course: CloudCourseSummary

    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    private let service: CloudLibraryService = CloudLibraryServiceFactory.makeDefault()

    @State private var detail: CloudCourseDetail?
    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    @State private var previewBook: CloudCourseBook?
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

                if let detail {
                    courseHeader(detail: detail)

                    Button {
                        Task { await copyEntireCourse(detail) }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text(String(localized: "cloud.course.downloadAll", locale: locale))
                        }
                    }
                    .buttonStyle(DSButton(style: .primary, size: .full))

                    LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                        ForEach(detail.books) { book in
                            CourseBookCard(
                                book: book,
                                onPreview: { previewBook = book },
                                onDownload: { Task { await copyBook(book, courseTitle: detail.title) } }
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(Text(course.title))
        .task { await loadDetail() }
        .refreshable { await loadDetail() }
        .sheet(item: $previewBook) { book in
            NavigationStack {
                CloudCourseBookPreviewView(courseTitle: course.title, book: book)
            }
        }
    }

    private func loadDetail() async {
        isLoading = true
        error = nil
        guard AppConfig.backendURL != nil else {
            isLoading = false
            let msg = String(localized: "banner.backend.missing.subtitle", locale: locale)
            error = msg
            bannerCenter.show(title: String(localized: "banner.backend.missing.title", locale: locale), subtitle: msg)
            detail = nil
            return
        }
        do {
            detail = try await service.fetchCourseDetail(id: course.id)
        } catch {
            self.error = (error as NSError).localizedDescription
            detail = nil
            bannerCenter.show(title: String(localized: "banner.cloud.loadFailed.title", locale: locale), subtitle: self.error)
        }
        isLoading = false
    }

    private func localName(for book: CloudCourseBook, courseTitle: String) -> String {
        "\(courseTitle) · \(book.title)"
    }

    private func copyBook(_ book: CloudCourseBook, courseTitle: String) async {
        guard AppConfig.backendURL != nil else {
            bannerCenter.show(title: String(localized: "banner.backend.missing.title", locale: locale), subtitle: String(localized: "banner.backend.missing.subtitle", locale: locale))
            return
        }
        let name = localName(for: book, courseTitle: courseTitle)
        localBank.addOrReplaceBook(name: name, items: book.items)
        localProgress.removeBook(name) // reset any stale progress for overwritten book
        let subtitle = "\(name) • " + String(format: String(localized: "bank.book.count", locale: locale), book.items.count)
        bannerCenter.show(title: String(localized: "banner.copiedToLocal.title", locale: locale), subtitle: subtitle)
    }

    private func copyEntireCourse(_ detail: CloudCourseDetail) async {
        for book in detail.books {
            await copyBook(book, courseTitle: detail.title)
        }
        bannerCenter.show(
            title: String(localized: "cloud.course.downloadAll.success", locale: locale),
            subtitle: detail.books.map { $0.title }.joined(separator: " • ")
        )
    }
    @ViewBuilder
    private func courseHeader(detail: CloudCourseDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let summary = detail.summary, !summary.isEmpty {
                Text(summary)
                    .dsType(DS.Font.body)
                    .foregroundStyle(.secondary)
            }
            if !detail.tags.isEmpty {
                Text(detail.tags.joined(separator: " • "))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            Text(String(format: String(localized: "cloud.course.bookCount", locale: locale), detail.bookCount))
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CourseBookCard: View {
    let book: CloudCourseBook
    let onPreview: () -> Void
    let onDownload: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(book.title)
                        .dsType(DS.Font.section)
                    if let summary = book.summary, !summary.isEmpty {
                        Text(summary)
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "text.book.closed")
                        .foregroundStyle(DS.Palette.primary.opacity(0.6))
                    Text(String(format: String(localized: "cloud.course.bookItemCount", locale: locale), book.itemCount))
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                    if let difficulty = book.difficulty {
                        Text(String(format: String(localized: "cloud.course.bookDifficulty", locale: locale), difficulty))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !book.tags.isEmpty {
                        Text(book.tags.joined(separator: " • "))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: DS.Spacing.sm) {
                    Button(action: onPreview) {
                        Text(String(localized: "cloud.preview", locale: locale))
                            .dsType(DS.Font.caption)
                    }
                    .buttonStyle(DSButton(style: .secondary, size: .compact))

                    Button(action: onDownload) {
                        Text(String(localized: "cloud.copyToLocal", locale: locale))
                            .dsType(DS.Font.caption)
                    }
                    .buttonStyle(DSButton(style: .secondary, size: .compact))

                }
            }
        }
    }
}

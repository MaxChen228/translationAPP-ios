import SwiftUI

struct CloudBankLibraryView: View {
    @ObservedObject var vm: CorrectionViewModel
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    private let service: CloudLibraryService = CloudLibraryServiceFactory.makeDefault()
    @State private var books: [CloudBookSummary] = []
    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    @Environment(\.locale) private var locale

    var body: some View {
        DSScrollContainer {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
                if let error { ErrorStateCard(title: error) }

                DSSectionHeader(titleKey: "cloud.books.title", subtitleKey: "cloud.books.subtitle", accentUnderline: true)

                if !isLoading && error == nil && books.isEmpty {
                    EmptyStateCard(title: String(localized: "cloud.books.empty", locale: locale), subtitle: String(localized: "cloud.common.retry", locale: locale), iconSystemName: "books.vertical")
                }

                LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(books) { b in
                        DSOutlineCard {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                    Text(b.name).dsType(DS.Font.section)
                    Text(String(format: String(localized: "bank.book.count", locale: locale), b.count)).dsType(DS.Font.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Button { Task { await copyBook(b) } } label: { DSIconLabel(textKey: "cloud.copyToLocal", systemName: "arrow.down.doc.fill") }
                                    .buttonStyle(DSButton(style: .secondary, size: .compact))
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .navigationTitle(Text("nav.cloudBooks"))
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        guard AppConfig.backendURL != nil else {
            isLoading = false
            let msg = String(localized: "banner.backend.missing.subtitle", locale: locale)
            error = msg
            bannerCenter.show(title: String(localized: "banner.backend.missing.title", locale: locale), subtitle: msg)
            books = []
            return
        }
        do {
            books = try await service.fetchBooks()
        } catch {
            self.error = (error as NSError).localizedDescription
            books = []
            bannerCenter.show(title: String(localized: "banner.cloud.loadFailed.title", locale: locale), subtitle: self.error)
        }
        isLoading = false
    }

    private func copyBook(_ s: CloudBookSummary) async {
        guard AppConfig.backendURL != nil else {
            bannerCenter.show(title: String(localized: "banner.backend.missing.title", locale: locale), subtitle: String(localized: "banner.backend.missing.subtitle", locale: locale))
            return
        }
        do {
            let detail = try await service.fetchBook(name: s.name)
            localBank.addOrReplaceBook(name: detail.name, items: detail.items)
            let subtitle = "\(detail.name) • " + String(format: String(localized: "bank.book.count", locale: locale), detail.items.count)
            bannerCenter.show(title: String(localized: "banner.copiedToLocal.title", locale: locale), subtitle: subtitle)
        } catch {
            bannerCenter.show(title: String(localized: "banner.copyFailed.title", locale: locale), subtitle: (error as NSError).localizedDescription)
        }
    }
}

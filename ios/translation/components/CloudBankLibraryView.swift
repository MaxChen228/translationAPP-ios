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
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
                if let error { ErrorStateCard(title: error) }

                DSSectionHeader(title: String(localized: "cloud.books.title", locale: locale), subtitle: String(localized: "cloud.books.subtitle", locale: locale), accentUnderline: true)

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
                                Button { Task { await copyBook(b) } } label: { Label { Text("cloud.copyToLocal") } icon: { Image(systemName: "arrow.down.doc.fill") } }
                                    .buttonStyle(DSSecondaryButtonCompact())
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle(Text("nav.cloudBooks"))
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        guard AppConfig.backendURL != nil else {
            isLoading = false
            let msg = "BACKEND_URL 未設定，無法瀏覽雲端題庫。"
            error = msg
            bannerCenter.show(title: "未設定後端", subtitle: msg)
            books = []
            return
        }
        do {
            books = try await service.fetchBooks()
        } catch {
            self.error = (error as NSError).localizedDescription
            books = []
        }
        isLoading = false
    }

    private func copyBook(_ s: CloudBookSummary) async {
        guard AppConfig.backendURL != nil else {
            bannerCenter.show(title: "未設定後端", subtitle: "請先設定 BACKEND_URL")
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

import SwiftUI

struct CloudBankLibraryView: View {
    @ObservedObject var vm: CorrectionViewModel
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    private let service: CloudLibraryService = CloudLibraryServiceFactory.makeDefault()
    @State private var books: [CloudBookSummary] = []
    @State private var isLoading: Bool = false
    @State private var error: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
                if let error { ErrorStateCard(title: error) }

                DSSectionHeader(title: "雲端題庫本", subtitle: "瀏覽精選題庫，複製到本機使用", accentUnderline: true)

                if !isLoading && error == nil && books.isEmpty {
                    EmptyStateCard(title: "目前沒有雲端題庫本", subtitle: "稍後再試，或檢查後端設定。", iconSystemName: "books.vertical")
                }

                LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(books) { b in
                        DSOutlineCard {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(b.name).dsType(DS.Font.section)
                                    Text("共 \(b.count) 題").dsType(DS.Font.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Button { Task { await copyBook(b) } } label: { Label("複製到本機", systemImage: "arrow.down.doc.fill") }
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
        .navigationTitle("瀏覽題庫本")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            books = try await service.fetchBooks()
        } catch {
            self.error = (error as NSError).localizedDescription
            books = []
        }
        isLoading = false
    }

    private func copyBook(_ s: CloudBookSummary) async {
        do {
            let detail = try await service.fetchBook(name: s.name)
            localBank.addOrReplaceBook(name: detail.name, items: detail.items)
            bannerCenter.show(title: "已複製到本機", subtitle: "\(detail.name) • \(detail.items.count) 題")
        } catch {
            bannerCenter.show(title: "複製失敗", subtitle: (error as NSError).localizedDescription)
        }
    }
}


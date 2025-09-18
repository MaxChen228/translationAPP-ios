import SwiftUI

struct CloudDeckLibraryView: View {
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    private let service: CloudLibraryService = CloudLibraryServiceFactory.makeDefault()
    @State private var decks: [CloudDeckSummary] = []
    @State private var isLoading: Bool = false
    @State private var error: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
                if let error { ErrorStateCard(title: error) }

                DSSectionHeader(title: "雲端單字卡集", subtitle: "瀏覽精選卡集，複製到本機使用", accentUnderline: true)

                if !isLoading && error == nil && decks.isEmpty {
                    EmptyStateCard(title: "目前沒有雲端單字卡集", subtitle: "稍後再試，或檢查後端設定。", iconSystemName: "rectangle.on.rectangle.angled")
                }

                LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(decks) { d in
                        DSOutlineCard {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(d.name).dsType(DS.Font.section)
                                    Text("共 \(d.count) 張").dsType(DS.Font.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Button { Task { await copyDeck(d) } } label: { Label("複製到本機", systemImage: "arrow.down.doc.fill") }
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
        .navigationTitle("瀏覽單字卡集")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            decks = try await service.fetchDecks()
        } catch {
            self.error = (error as NSError).localizedDescription
            decks = []
        }
        isLoading = false
    }

    private func copyDeck(_ d: CloudDeckSummary) async {
        do {
            let detail = try await service.fetchDeckDetail(id: d.id)
            _ = decksStore.add(name: detail.name, cards: detail.cards)
            bannerCenter.show(title: "已複製到本機", subtitle: "\(detail.name) • \(detail.cards.count) 張")
        } catch {
            bannerCenter.show(title: "複製失敗", subtitle: (error as NSError).localizedDescription)
        }
    }
}


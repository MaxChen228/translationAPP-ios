import SwiftUI

struct CloudDeckLibraryView: View {
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    private let service: CloudLibraryService = CloudLibraryServiceFactory.makeDefault()
    @State private var decks: [CloudDeckSummary] = []
    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
                if let error { ErrorStateCard(title: error) }

                DSSectionHeader(titleKey: "cloud.decks.title", subtitleKey: "cloud.decks.subtitle", accentUnderline: true)

                if !isLoading && error == nil && decks.isEmpty {
                    EmptyStateCard(title: String(localized: "cloud.decks.empty", locale: locale), subtitle: String(localized: "cloud.common.retry", locale: locale), iconSystemName: "rectangle.on.rectangle.angled")
                }

                LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(decks) { d in
                        DSOutlineCard {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                    Text(d.name).dsType(DS.Font.section)
                    Text(String(format: String(localized: "deck.cards.count", locale: locale), d.count)).dsType(DS.Font.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Button { Task { await copyDeck(d) } } label: { DSIconLabel(textKey: "cloud.copyToLocal", systemName: "arrow.down.doc.fill") }
                                    .buttonStyle(DSButton(style: .secondary, size: .compact))
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
        .navigationTitle(Text("nav.cloudDecks"))
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
            decks = []
            return
        }
        do {
            decks = try await service.fetchDecks()
        } catch {
            self.error = (error as NSError).localizedDescription
            decks = []
            bannerCenter.show(title: String(localized: "banner.cloud.loadFailed.title", locale: locale), subtitle: self.error)
        }
        isLoading = false
    }

    private func copyDeck(_ d: CloudDeckSummary) async {
        guard AppConfig.backendURL != nil else {
            bannerCenter.show(title: String(localized: "banner.backend.missing.title", locale: locale), subtitle: String(localized: "banner.backend.missing.subtitle", locale: locale))
            return
        }
        do {
            let detail = try await service.fetchDeckDetail(id: d.id)
            _ = decksStore.add(name: detail.name, cards: detail.cards)
            let subtitle = "\(detail.name) • " + String(format: String(localized: "deck.cards.count", locale: locale), detail.cards.count)
            bannerCenter.show(title: String(localized: "banner.copiedToLocal.title", locale: locale), subtitle: subtitle)
        } catch {
            bannerCenter.show(title: String(localized: "banner.copyFailed.title", locale: locale), subtitle: (error as NSError).localizedDescription)
        }
    }
}

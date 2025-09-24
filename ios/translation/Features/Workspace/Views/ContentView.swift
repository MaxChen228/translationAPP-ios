//
//  ContentView.swift
//  translation
//
//  Created by 陳亮宇 on 2025/9/14.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var vm: CorrectionViewModel
    @ObservedObject private var session: CorrectionSessionStore
    @ObservedObject private var mergeController: ErrorMergeController
    @ObservedObject private var practice: PracticeSessionCoordinator
    @EnvironmentObject private var savedStore: SavedErrorsStore
    @EnvironmentObject private var bannerCenter: BannerCenter

    init(correctionRunner: CorrectionRunning = CorrectionServiceFactory.makeDefault()) {
        let viewModel = CorrectionViewModel(correctionRunner: correctionRunner)
        _vm = StateObject(wrappedValue: viewModel)
        _session = ObservedObject(initialValue: viewModel.session)
        _mergeController = ObservedObject(initialValue: viewModel.merge)
        _practice = ObservedObject(initialValue: viewModel.practice)
    }

    init(vm: CorrectionViewModel) {
        _vm = StateObject(wrappedValue: vm)
        _session = ObservedObject(initialValue: vm.session)
        _mergeController = ObservedObject(initialValue: vm.merge)
        _practice = ObservedObject(initialValue: vm.practice)
    }

    @FocusState private var focused: Field?
    enum Field { case zh, en }
    @State private var showSavedSheet: Bool = false // legacy; replaced by NavigationLink

    @Environment(\.locale) private var locale
    var body: some View {
        DSScrollContainer {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    HStack(alignment: .firstTextBaseline) {
                        DSSectionHeader(titleKey: "content.zh.title", subtitleKey: "content.zh.subtitle", accentUnderline: true)
                        Spacer()
                        NavigationLink {
                            BankBooksView(vm: vm)
                        } label: {
                            DSIconLabel(textKey: "content.bank", systemName: "books.vertical")
                        }
                        .buttonStyle(DSButton(style: .secondary, size: .full))
                        .frame(width: DS.ButtonSize.small)
                    }
                    ChinesePromptView(text: session.inputZh)

                    // Subtle separator to structure the page（以淡藍髮絲線）
                    DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border))

                    HintListSection(
                        hints: session.practicedHints,
                        isExpanded: vm.binding(\.showPracticedHints),
                        savedPredicate: vm.isHintSaved,
                        onTapSave: { handleHintSave($0) }
                    )

                    DSSectionHeader(titleKey: "content.en.title", subtitleKey: "content.en.subtitle", accentUnderline: true)
                    DSCard {
                        DSTextArea(text: vm.binding(\.inputEn), minHeight: 140, placeholder: String(localized: "content.en.placeholder", locale: locale), isFocused: focused == .en, ruled: true, disableAutocorrection: true)
                            .focused($focused, equals: .en)
                    }

                    if let res = session.response {
                        // Separate inputs from results visually（以淡藍髮絲線）
                        DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border))

                            ResultsSectionView(
                                res: res,
                                inputZh: session.inputZh,
                                inputEn: session.inputEn,
                                highlights: session.filteredHighlights(),
                            correctedHighlights: session.filteredCorrectedHighlights(),
                            errors: session.filteredErrors(),
                            selectedErrorID: vm.binding(\.selectedErrorID),
                            filterType: vm.binding(\.filterType),
                            popoverError: vm.binding(\.popoverError),
                            mode: vm.binding(\.cardMode),
                                applySuggestion: { session.applySuggestion(for: $0) },
                                onSave: { item in
                                let trimmedSuggestion = item.suggestion?.trimmingCharacters(in: .whitespacesAndNewlines)
                                let title = (trimmedSuggestion?.isEmpty == false ? trimmedSuggestion : nil) ?? item.span
                                savedStore.addKnowledge(
                                    title: title,
                                    explanation: item.explainZh,
                                    correctExample: res.corrected,
                                    note: nil,
                                    savedAt: Date()
                                )
                                },
                                onSavePracticeRecord: {
                                    vm.savePracticeRecord()
                                },
                            mergeController: mergeController,
                            session: session,
                            onEnterMergeMode: { vm.enterMergeMode(initialErrorID: $0) },
                            onToggleSelection: { vm.toggleMergeSelection(for: $0) },
                            onMergeConfirm: { await vm.performMergeIfNeeded() },
                            onCancelMerge: { vm.cancelMergeMode() }
                        )
                    }

                    if !mergeController.isMergeMode {
                        // 內嵌於頁面底部的操作列（不再懸浮）
                        HStack(spacing: DS.Spacing.md) {
                            Button {
                                if AppConfig.correctAPIURL == nil {
                                    bannerCenter.show(title: String(localized: "banner.backend.missing.title", locale: locale), subtitle: String(localized: "banner.backend.missing.subtitle", locale: locale))
                                } else {
                                    Task { await vm.runCorrection() }
                                    focused = nil
                                }
                            } label: {
                                Group {
                                    if vm.isLoading {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .tint(.white)
                                            Text("content.correcting")
                                        }
                                    } else {
                                        DSIconLabel(textKey: "content.correct", systemName: "checkmark.seal.fill")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(DSButton(style: .primary, size: .full))
                            .disabled(vm.isLoading)

                            Button {
                                vm.loadNextPractice()
                                focused = .en
                            } label: {
                                DSIconLabel(textKey: "content.next", systemName: "arrow.right.circle.fill")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .buttonStyle(DSButton(style: .secondary, size: .full))
                            .disabled(vm.isLoading || practice.currentBankItemId == nil)

                            Button(role: .destructive) {
                                vm.reset()
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: DS.IconSize.toolbarIcon, height: DS.IconSize.toolbarIcon)
                            }
                            .buttonStyle(DSButton(style: .secondary, size: .full))
                            .frame(width: DS.ButtonSize.compact)
                            .disabled(vm.isLoading)
                        }
                        .padding(.top, DS.Spacing.md)
                    }
                }
        }
        .disabled(vm.isLoading)
        .navigationTitle(Text("nav.translate"))
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focused = nil
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        PracticeRecordsListView()
                    } label: {
                        Image(systemName: "doc.text")
                    }
                    .accessibilityLabel(Text("a11y.openPracticeRecords"))

                    NavigationLink {
                        SavedJSONListSheet()
                            .environmentObject(savedStore)
                    } label: {
                        Image(systemName: "tray.full")
                    }
                    .accessibilityLabel(Text("a11y.openSavedJSON"))
                }
            }
        .overlay(alignment: .center) {
            if vm.isLoading { LoadingOverlay() }
        }
        // legacy sheet removed; now navigates to a page via NavigationLink
        .onDisappear {
            vm.resetHintSavedMarkers()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SavedErrorsStore())
        .environmentObject(BannerCenter())
}

private extension ContentView {
    func localizedString(for key: String) -> String {
        if let path = Bundle.main.path(forResource: locale.identifier, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return NSLocalizedString(key, comment: "")
    }

    func handleHintSave(_ hint: BankHint) {
        let categoryName = localizedString(for: hint.category.displayNameKey)
        let prompt = session.inputZh
        let result = savedStore.addHint(hint, categoryLabel: categoryName, prompt: prompt)
        let successTitle = String(localized: "hint.save.success", locale: locale)
        let duplicateTitle = String(localized: "hint.save.duplicate", locale: locale)

        switch result {
        case .added:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            bannerCenter.show(title: successTitle)
            vm.markHintSaved(hint.id)
        case .duplicate:
            bannerCenter.show(title: duplicateTitle)
        }
    }
}

//
//  ContentView.swift
//  translation
//
//  Created by 陳亮宇 on 2025/9/14.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm: CorrectionViewModel
    @EnvironmentObject private var savedStore: SavedErrorsStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    init(correctionRunner: CorrectionRunning = CorrectionServiceFactory.makeDefault()) {
        _vm = StateObject(wrappedValue: CorrectionViewModel(correctionRunner: correctionRunner))
    }
    init(vm: CorrectionViewModel) {
        _vm = StateObject(wrappedValue: vm)
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
                    ChinesePromptView(text: vm.inputZh)

                    // Subtle separator to structure the page（以淡藍髮絲線）
                    DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border))

                    HintListSection(hints: vm.practicedHints, isExpanded: $vm.showPracticedHints)

                    DSSectionHeader(titleKey: "content.en.title", subtitleKey: "content.en.subtitle", accentUnderline: true)
                    DSCard {
                        DSTextArea(text: $vm.inputEn, minHeight: 140, placeholder: String(localized: "content.en.placeholder", locale: locale), isFocused: focused == .en, ruled: true, disableAutocorrection: true)
                            .focused($focused, equals: .en)
                    }

                    if let res = vm.response {
                        // Separate inputs from results visually（以淡藍髮絲線）
                        DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border))

                        ResultsSectionView(
                            res: res,
                            inputZh: vm.inputZh,
                            inputEn: vm.inputEn,
                            highlights: vm.filteredHighlights,
                            correctedHighlights: vm.filteredCorrectedHighlights,
                            errors: vm.filteredErrors,
                            selectedErrorID: $vm.selectedErrorID,
                            filterType: $vm.filterType,
                            popoverError: $vm.popoverError,
                            mode: $vm.cardMode,
                            applySuggestion: { vm.applySuggestion(for: $0) },
                            onSave: { item in
                                let payload = ErrorSavePayload(
                                    error: item,
                                    inputEn: vm.inputEn,
                                    correctedEn: res.corrected,
                                    inputZh: vm.inputZh,
                                    savedAt: Date()
                                )
                                savedStore.add(payload: payload)
                            },
                            onSavePracticeRecord: {
                                vm.savePracticeRecord()
                            },
                            isMergeMode: vm.isMergeMode,
                            mergeSelection: vm.mergeSelection,
                            mergeInFlight: vm.mergeInFlight,
                            mergedHighlightID: vm.lastMergedErrorID,
                            onEnterMergeMode: { vm.enterMergeMode(initialErrorID: $0) },
                            onToggleSelection: { vm.toggleMergeSelection(for: $0) },
                            onMergeConfirm: { await vm.performMergeIfNeeded() },
                            onCancelMerge: { vm.cancelMergeMode() }
                        )
                    }

                    if !vm.isMergeMode {
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
                                Task { await vm.loadNextPractice() }
                                focused = .en
                            } label: {
                                DSIconLabel(textKey: "content.next", systemName: "arrow.right.circle.fill")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .buttonStyle(DSButton(style: .secondary, size: .full))
                            .disabled(vm.isLoading || vm.currentBankItemId == nil)

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
    }
}

#Preview { ContentView() }

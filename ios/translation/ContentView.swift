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
    init(service: AIService = AIServiceFactory.makeDefault()) {
        _vm = StateObject(wrappedValue: CorrectionViewModel(service: service))
    }
    init(vm: CorrectionViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
    @FocusState private var focused: Field?
    enum Field { case zh, en }
    @State private var showSavedSheet: Bool = false // legacy; replaced by NavigationLink

    @Environment(\.locale) private var locale
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    HStack(alignment: .firstTextBaseline) {
                        DSSectionHeader(title: String(localized: "content.zh.title", locale: locale), subtitle: String(localized: "content.zh.subtitle", locale: locale), accentUnderline: true)
                        Spacer()
                        NavigationLink {
                            BankBooksView(vm: vm)
                        } label: {
                            Label { Text("content.bank") } icon: { Image(systemName: "books.vertical") }
                        }
                        .buttonStyle(DSSecondaryButton())
                        .frame(width: 92)
                    }
                    ChinesePromptView(text: vm.inputZh)

                    // Subtle separator to structure the page（以淡藍髮絲線）
                    DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border))

                    HintListSection(hints: vm.practicedHints, isExpanded: $vm.showPracticedHints)

                    DSSectionHeader(title: String(localized: "content.en.title", locale: locale), subtitle: String(localized: "content.en.subtitle", locale: locale), accentUnderline: true)
                    DSCard {
                        DSTextArea(text: $vm.inputEn, minHeight: 140, placeholder: String(localized: "content.en.placeholder", locale: locale), isFocused: focused == .en, ruled: true)
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
                            }
                        )
                    }

                    // 內嵌於頁面底部的操作列（不再懸浮）
                    HStack(spacing: DS.Spacing.md) {
                        Button {
                            Task { await vm.runCorrection() }
                            focused = nil
                        } label: {
                            Group {
                                if vm.isLoading {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .tint(.white)
                                        Text("content.correcting")
                                    }
                                } else {
                                    Label { Text("content.correct") } icon: { Image(systemName: "checkmark.seal.fill") }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DSPrimaryButton())
                        .disabled(vm.isLoading)

                        // 下一題（略過已完成）：需有題庫關聯與 BACKEND_URL
                        Button {
                            Task { await vm.loadNextPractice() }
                            focused = .en
                        } label: {
                            Label { Text("content.next") } icon: { Image(systemName: "arrow.right.circle.fill") }
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        .buttonStyle(DSSecondaryButton())
                        .disabled(vm.isLoading || vm.currentBankItemId == nil)

                        Button(role: .destructive) {
                            vm.reset()
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(DSSecondaryButton())
                        .frame(width: 64)
                        .disabled(vm.isLoading)
                    }
                    .padding(.top, DS.Spacing.md)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
            .disabled(vm.isLoading)
            .background(DS.Palette.background)
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
                ToolbarItem(placement: .topBarTrailing) {
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

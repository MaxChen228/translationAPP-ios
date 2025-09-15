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
    @State private var showSavedSheet: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    HStack(alignment: .firstTextBaseline) {
                        DSSectionHeader(title: "中文原文", subtitle: "輸入要翻成英文的句子", accentUnderline: true)
                        Spacer()
                        NavigationLink {
                            BankBooksView(vm: vm)
                        } label: {
                            Label("題庫", systemImage: "books.vertical")
                        }
                        .buttonStyle(DSSecondaryButton())
                        .frame(width: 92)
                    }
                    ChinesePromptView(text: vm.inputZh)

                    // Subtle separator to structure the page（以淡藍髮絲線）
                    DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(0.35))

                    HintListSection(hints: vm.practicedHints, isExpanded: $vm.showPracticedHints)

                    DSSectionHeader(title: "我的英文", subtitle: "先輸入你的嘗試，再按下批改", accentUnderline: true)
                    DSCard {
                        DSTextArea(text: $vm.inputEn, minHeight: 140, placeholder: "例如：I go to the shop yesterday to buy some fruits.", isFocused: focused == .en, ruled: true)
                            .focused($focused, equals: .en)
                    }

                    // Separate inputs from results visually（以淡藍髮絲線）
                    DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(0.35))

                    if let res = vm.response {
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
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, 100) // leave space for sticky bar
            }
            .disabled(vm.isLoading)
            .background(DS.Palette.background)
            .navigationTitle("中英翻譯批改")
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
                    Button {
                        showSavedSheet = true
                    } label: {
                        Image(systemName: "tray.full")
                    }
                    .accessibilityLabel("查看已儲存的錯誤 JSON")
                }
            }
                .safeAreaInset(edge: .bottom) {
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
                                    Text("批改中…")
                                }
                            } else {
                                Label("批改", systemImage: "checkmark.seal.fill")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSPrimaryButton())
                    .disabled(vm.isLoading)

                    // 下一題（略過已完成）：需有題庫關聯與 BANK_BASE_URL
                    Button {
                        Task { await vm.loadNextPractice() }
                        focused = .en
                    } label: {
                        Label("下一題", systemImage: "arrow.right.circle.fill")
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }
                    .buttonStyle(DSSecondaryButton())
                    .disabled(vm.isLoading || vm.currentBankItemId == nil || AppConfig.bankBaseURL == nil)

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
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(.ultraThinMaterial)
                .dsTopHairline(color: DS.Brand.scheme.babyBlue.opacity(0.35)) // Hairline on top of sticky bar
                .disabled(vm.isLoading)
        }
        .overlay(alignment: .center) {
            if vm.isLoading { LoadingOverlay() }
        }
        .sheet(isPresented: $showSavedSheet) {
            SavedJSONListSheet()
                .environmentObject(savedStore)
        }
    }
}

#Preview { ContentView() }

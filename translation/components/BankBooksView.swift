import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct BankBooksView: View {
    @ObservedObject var vm: CorrectionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var books: [BankService.BankBook] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var isImporting = false
    @State private var importMessage: String? = nil
    @State private var showImportAlert: Bool = false
    private let service = BankService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSSectionHeader(
                    title: "題庫本",
                    subtitle: "選擇一個書本開始練習",
                    accentUnderline: true
                )
                if let error {
                    DSCard {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(error)
                                .dsType(DS.Font.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if isLoading {
                    placeholderCard
                } else if books.isEmpty {
                    DSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("目前沒有題庫本")
                                .dsType(DS.Font.bodyEmph)
                            Text("下拉以重新整理，或稍後再試。")
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    let cols = [GridItem(.adaptive(minimum: 160), spacing: 12)]
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(books) { book in
                            NavigationLink {
                                BankListView(vm: vm, tag: book.name, onPractice: { dismiss() })
                            } label: {
                                BankBookCard(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle("題庫本")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await importFromClipboard() }
                } label: {
                    Label("匯入", systemImage: "doc.on.clipboard")
                }
                .disabled(isLoading || isImporting)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .onAppear { AppLog.uiInfo("[books] appear count=\(books.count)") }
        .alert(importMessage ?? "", isPresented: $showImportAlert) {
            Button("好") { showImportAlert = false; importMessage = nil }
        }
    }

    private var placeholderCard: some View {
        let cols = [GridItem(.adaptive(minimum: 160), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6).fill(DS.Palette.border.opacity(0.35)).frame(width: 100, height: 16)
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6).fill(DS.Palette.border.opacity(0.25)).frame(width: 60, height: 12)
                        RoundedRectangle(cornerRadius: 6).fill(DS.Palette.border.opacity(0.25)).frame(width: 90, height: 12)
                        Spacer(minLength: 0)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .stroke(DS.Palette.border.opacity(0.3), lineWidth: 0.5)
                )
            }
        }
        .redacted(reason: .placeholder)
    }

    private func load() async {
        isLoading = true
        error = nil
        do { books = try await service.fetchBooks() } catch { self.error = (error as NSError).localizedDescription }
        isLoading = false
    }

    private func importFromClipboard() async {
        #if os(iOS)
        guard let raw = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            importMessage = "剪貼簿沒有可匯入的文字"
            showImportAlert = true
            return
        }
        #else
        let raw = ""
        #endif
        isImporting = true
        defer { isImporting = false }
        do {
            let result = try await service.importClipboard(text: raw, defaultTag: nil, replace: false)
            await MainActor.run {
                importMessage = "已匯入 \(result.imported) 題"
                showImportAlert = true
            }
            await load()
        } catch {
            await MainActor.run {
                importMessage = (error as NSError).localizedDescription
                showImportAlert = true
            }
        }
    }
}

private struct BankBookRow: View {
    let book: BankService.BankBook
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(book.name.capitalized)
                    .dsType(DS.Font.section)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text("共 \(book.count) 題")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)

                    TagLabel(text: "難度 \(book.difficultyMin)-\(book.difficultyMax)", color: DS.Palette.primary)
                }
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(DS.Palette.surface)
    }
}

private struct BankBookCard: View {
    let book: BankService.BankBook
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book.name.capitalized)
                .dsType(DS.Font.section)
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Text("共 \(book.count) 題")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)

                TagLabel(text: "難度 \(book.difficultyMin)-\(book.difficultyMax)", color: DS.Palette.primary)

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.border.opacity(0.3), lineWidth: 0.5)
        )
        .dsCardShadow()
    }
}

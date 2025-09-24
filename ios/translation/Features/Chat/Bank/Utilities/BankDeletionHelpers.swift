import Foundation
import SwiftUI

struct BankDeletionMessageBuilder {
    static func folderDeleteMessage(bookCount: Int, locale: Locale) -> String {
        String.localizedStringWithFormat(
            String(localized: "bank.confirm.deleteFolder.message", locale: locale),
            bookCount
        )
    }
}

@MainActor
struct BankCascadeDeletionService {
    static func deleteBooks(
        _ names: [String],
        localBank: LocalBankStore,
        folders: BankFoldersStore,
        progress: LocalBankProgressStore,
        order: BankBooksOrderStore
    ) {
        guard !names.isEmpty else { return }
        for name in names {
            localBank.remove(name)
            folders.remove(bookName: name)
            progress.removeBook(name)
            order.removeFromRoot(name)
        }
    }
}

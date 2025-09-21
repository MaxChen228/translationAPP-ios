import SwiftUI

struct DSIconLabel: View {
    let textKey: LocalizedStringKey?
    let text: String?
    let systemName: String

    init(textKey: LocalizedStringKey, systemName: String) {
        self.textKey = textKey
        self.text = nil
        self.systemName = systemName
    }

    init(text: String, systemName: String) {
        self.textKey = nil
        self.text = text
        self.systemName = systemName
    }

    var body: some View {
        Label {
            Group {
                if let textKey {
                    Text(textKey)
                } else if let text {
                    Text(text)
                } else {
                    EmptyView()
                }
            }
        } icon: {
            Image(systemName: systemName)
        }
    }
}
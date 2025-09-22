import SwiftUI

extension View {
    func shelfConditionalDrag(_ isEnabled: Bool, provider: @escaping () -> NSItemProvider) -> some View {
        Group {
            if isEnabled {
                self.onDrag { provider() }
            } else {
                self
            }
        }
    }
}

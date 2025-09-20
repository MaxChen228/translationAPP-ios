import Foundation
import SwiftUI

@MainActor
final class RandomPracticeStore: ObservableObject {
    @AppStorage("random.excludeCompleted") var excludeCompleted: Bool = true
}


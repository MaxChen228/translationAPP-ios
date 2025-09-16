import SwiftUI

// Lightweight, view-agnostic drag models for overlay-based DnD

enum DragItemID: Hashable, Codable {
    case deck(UUID)
    case folder(UUID)

    var raw: String {
        switch self { case .deck(let id): return "deck:\(id.uuidString)"; case .folder(let id): return "folder:\(id.uuidString)" }
    }
}

struct DragPreview: Identifiable {
    let id = UUID()
    let view: AnyView
    let size: CGSize
}

final class DragState: ObservableObject {
    @Published var isDragging: Bool = false
    @Published var itemID: DragItemID? = nil
    @Published var location: CGPoint = .zero
    @Published var preview: DragPreview? = nil
    @Published var hoverTarget: DragItemID? = nil
    @Published var placeholderIndex: Int? = nil

    func reset() {
        isDragging = false
        itemID = nil
        location = .zero
        preview = nil
        hoverTarget = nil
        placeholderIndex = nil
    }
}

// Each tile reports its frame in a named coordinate space
struct TileFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { $1 }) }
}


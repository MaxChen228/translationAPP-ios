import SwiftUI

// Drag overlay which renders the preview and basic hover indicator.
struct DragLayer<Content: View>: View {
    @ObservedObject var state: DragState
    var content: () -> Content
    var body: some View {
        ZStack(alignment: .topLeading) {
            content()
            if let p = state.preview, state.isDragging {
                p.view
                    .frame(width: p.size.width, height: p.size.height)
                    .position(x: state.location.x, y: state.location.y)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }
}

// Helper for capturing each tile's frame in a coordinate space.
struct TileFrameReporter: ViewModifier {
    var id: String
    var coordinateSpace: CoordinateSpace
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear.preference(key: TileFrameKey.self, value: [id: geo.frame(in: coordinateSpace)])
            })
    }
}

extension View {
    func reportTileFrame(id: String, in space: CoordinateSpace) -> some View {
        modifier(TileFrameReporter(id: id, coordinateSpace: space))
    }
}


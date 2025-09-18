import SwiftUI

// Reusable ultra-thin separators and edge hairlines.
struct DSSeparator: View {
    enum Axis { case horizontal, vertical }

    var axis: Axis = .horizontal
    var color: Color = DS.Palette.border.opacity(DS.Opacity.border)

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: axis == .vertical ? DS.Metrics.hairline : nil,
                   height: axis == .horizontal ? DS.Metrics.hairline : nil)
            .accessibilityHidden(true)
    }
}

extension View {
    func dsTopHairline(color: Color = DS.Palette.border.opacity(DS.Opacity.border)) -> some View {
        overlay(alignment: .top) {
            DSSeparator(color: color)
        }
    }

    func dsBottomHairline(color: Color = DS.Palette.border.opacity(DS.Opacity.border)) -> some View {
        overlay(alignment: .bottom) {
            DSSeparator(color: color)
        }
    }
}

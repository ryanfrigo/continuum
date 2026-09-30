import SwiftUI

extension View {
    /// The small uppercase label over a readout, the same on every screen.
    func readoutLabel(size: CGFloat = 9) -> some View {
        font(.system(size: size, weight: .semibold, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.4))
    }
}

import SwiftUI

/// "▲4": how far a consistency number moved over the last 7 days. Always
/// grey, up or down: it's a readout, and a dip isn't a failure.
/// Shared by the app and the widget.
struct TrendLabel: View {
    let trend: Int
    var size: CGFloat = 11
    /// Appended to the number, e.g. " this week".
    var suffix: String = ""

    var body: some View {
        HStack(spacing: size * 0.2) {
            Image(systemName: trend > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: size * 0.55))
            Text("\(abs(trend))\(suffix)")
                .font(.system(size: size, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(Color.white.opacity(0.45))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trend > 0 ? "up \(trend) points this week" : "down \(-trend) points this week")
    }
}

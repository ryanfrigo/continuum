import SwiftUI

/// "↑4": how far a consistency number moved over the last 7 days. Up takes
/// the habit's colour; down is grey, never red — a dip isn't a failure.
/// Shared by the app and the widget.
struct TrendLabel: View {
    let trend: Int
    var color: Color
    var size: CGFloat = 11
    /// Appended to the number, e.g. " this week".
    var suffix: String = ""

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: trend > 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: size * 0.8, weight: .heavy))
            Text("\(abs(trend))\(suffix)")
                .font(.system(size: size, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(trend > 0 ? color : Color.white.opacity(0.4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trend > 0 ? "up \(trend) this week" : "down \(-trend) this week")
    }
}

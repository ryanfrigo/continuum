import SwiftUI

/// The home screen's readouts, set like an instrument panel: every habit
/// pooled into one consistency figure, the week's movement, and today's
/// count. Hidden until a habit has a number — an empty "—%" is just noise on
/// day one.
struct ConsistencyHeader: View {
    let tally: ConsistencyTally
    let trend: Int?
    let doneToday: Int
    let habitCount: Int
    let accent: Color

    private let valueSize: CGFloat = 20

    var body: some View {
        if let percent = tally.percent {
            HStack(alignment: .top, spacing: 0) {
                readout("CONSISTENT") {
                    Text("\(percent)%")
                        .foregroundStyle(accent)
                        // A little phosphor glow, like an old terminal
                        .shadow(color: accent.opacity(0.5), radius: 6)
                        .contentTransition(.numericText(value: Double(percent)))
                        .animation(.snappy, value: percent)
                }
                divider
                readout("THIS WEEK") {
                    if let trend, trend != 0 {
                        TrendLabel(trend: trend, color: accent, size: valueSize)
                    } else {
                        // Too new for a trend, or flat
                        Text(trend == nil ? "–" : "±0")
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                divider
                readout("TODAY") {
                    Text("\(doneToday)/\(habitCount)")
                        .foregroundStyle(.white.opacity(doneToday == habitCount ? 0.9 : 0.6))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText(percent))
        }
    }

    private func readout<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.35))
            value()
                .font(.system(size: valueSize, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(width: 1, height: 36)
            .padding(.trailing, 14)
    }

    private func accessibilityText(_ percent: Int) -> String {
        var parts = ["\(percent) percent consistent over the last 66 days"]
        if let trend, trend != 0 {
            parts.append(trend > 0 ? "up \(trend) this week" : "down \(-trend) this week")
        }
        parts.append("\(doneToday) of \(habitCount) done today")
        return parts.joined(separator: ", ")
    }
}

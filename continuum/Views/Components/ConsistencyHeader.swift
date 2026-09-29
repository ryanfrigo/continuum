import SwiftUI

/// The home screen's number: every habit pooled into one consistency figure,
/// with the week's movement and today's count beside it. Hidden until a habit
/// has a number — an empty "—%" is just noise on day one.
struct ConsistencyHeader: View {
    let tally: ConsistencyTally
    let trend: Int?
    let doneToday: Int
    let habitCount: Int
    let accent: Color

    var body: some View {
        if let percent = tally.percent {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(percent)")
                            .font(.system(size: 54, weight: .heavy))
                            .contentTransition(.numericText(value: Double(percent)))
                            .animation(.snappy, value: percent)
                        Text("%")
                            .font(.system(size: 26, weight: .heavy))
                    }
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.3), radius: 14)

                    Text("CONSISTENT · LAST 66 DAYS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    if let trend, trend != 0 {
                        TrendLabel(trend: trend, color: accent, size: 13, suffix: " this week")
                    }
                    Text("\(doneToday) of \(habitCount) today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(doneToday == habitCount ? 0.75 : 0.45))
                }
                .padding(.bottom, 2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText(percent))
        }
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

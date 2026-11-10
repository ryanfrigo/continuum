import ActivityKit
import SwiftUI
import WidgetKit

/// The evening Live Activity's look: open habits and what today does to each
/// number. After midnight it goes stale and says the day closed.
struct EveningLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EveningActivityAttributes.self) { context in
            EveningLockScreenView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.state.open) open")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(HabitPalette.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("before midnight")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    EveningRows(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(HabitPalette.accent)
            } compactTrailing: {
                Text("\(context.state.open)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(HabitPalette.accent)
            } minimal: {
                Text("\(context.state.open)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(HabitPalette.accent)
            }
        }
    }
}

struct EveningLockScreenView: View {
    let state: EveningActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("continuum")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(isStale ? "day closed" : "\(state.open) open · before midnight")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(HabitPalette.accent)
            }
            if !isStale {
                EveningRows(state: state)
            }
        }
        .padding(16)
    }
}

struct EveningRows: View {
    let state: EveningActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(state.rows, id: \.self) { row in
                HStack {
                    Text(row.name)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(numbers(row))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            let more = state.open - state.rows.count
            if more > 0 {
                Text("+\(more) more")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    /// "62% → 64%", or "first day" for a habit with no number yet.
    private func numbers(_ row: EveningActivityPlan.Row) -> String {
        guard let now = row.percent else { return "first day" }
        guard let next = row.ifDone, next != now else { return "\(now)%" }
        return "\(now)% → \(next)%"
    }
}

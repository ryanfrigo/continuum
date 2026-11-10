import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// The evening Live Activity: from 9 pm, the habits still open today on the
/// lock screen and in the Dynamic Island, until they're done or the day ends.
/// One activity for all open habits, not one each. Opt-in (Settings).
enum EveningActivityPlan {
    /// When it shows up: the last three hours of the day.
    static let startHour = 21
    /// Names shown; the rest are a count.
    static let maxRows = 3

    struct Row: Codable, Hashable {
        var name: String
        /// Consistency now; nil before the habit has a number.
        var percent: Int?
        /// What marking today makes it.
        var ifDone: Int?
    }

    /// Open habits (not done today), in home-screen order.
    static func rows(_ habits: [(name: String, completed: Set<Int>)], todayKey: Int) -> (rows: [Row], open: Int) {
        let open = habits.filter { !$0.completed.contains(todayKey) }
        let rows = open.prefix(maxRows).map { habit in
            Row(
                name: habit.name,
                percent: HabitMath.consistency(completed: habit.completed, todayKey: todayKey).percent,
                ifDone: HabitMath.consistency(completed: habit.completed.union([todayKey]), todayKey: todayKey).percent
            )
        }
        return (Array(rows), open.count)
    }

    /// 9 pm today, or now if that's already passed.
    static func start(now: Date, calendar: Calendar = .current) -> Date {
        let nine = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now) ?? now
        return max(now, nine)
    }

    /// The end of the local day: the activity goes stale here.
    static func midnight(after now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
    }
}

#if canImport(ActivityKit) && os(iOS)
struct EveningActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var rows: [EveningActivityPlan.Row]
        /// All open habits, including those not listed.
        var open: Int
    }

    /// The day it's for, so yesterday's never survives into today.
    var dayKey: Int
}
#endif

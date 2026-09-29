import Foundation
import UserNotifications

// MARK: - Plan
// What should be pending is a pure function of habit state and the clock, so
// it's unit-tested here and the system center only ever gets reconciled to it.

/// One notification the app wants pending.
struct PlannedNotification: Equatable {
    let identifier: String
    let title: String
    let body: String
    let dayKey: Int
    let hour: Int
    let minute: Int

    /// Chronological sort key, e.g. 202609142000.
    var fireOrder: Int { dayKey * 10_000 + hour * 100 + minute }
}

enum NotificationPlanner {
    /// Short horizon: content is computed now, and only the next day or two can
    /// be worded truthfully. The app re-plans on every activation and day change.
    static let daysAhead = 3
    /// The never-miss-twice alert, on the evening after a missed day.
    static let missAlertHour = 20
    /// iOS keeps at most 64 pending requests per app and silently drops the rest.
    static let systemPendingLimit = 64

    /// Every notification for every habit, soonest first, capped at the system limit
    /// so it's the far-future ones that go missing, not tomorrow's.
    static func plan(for habits: [Habit], todayKey: Int, hour: Int, minute: Int) -> [PlannedNotification] {
        let all = habits.flatMap { plan(for: $0, todayKey: todayKey, hour: hour, minute: minute) }
        return Array(all.sorted { $0.fireOrder < $1.fireOrder }.prefix(systemPendingLimit))
    }

    static func plan(for habit: Habit, todayKey: Int, hour: Int, minute: Int) -> [PlannedNotification] {
        // The per-habit reminder toggle is the one switch for everything this
        // habit sends, the evening alert included.
        guard habit.reminderEnabled else { return [] }

        let completed = habit.completedDayKeys
        let doneToday = completed.contains(todayKey)
        let yesterdayKey = ContinuumDay.key(byAdding: -1, to: todayKey)
        // "Day one" copy is only true for an empty grid; a habit with 40 days
        // behind it should never be told it has never started. Day keys are
        // yyyymmdd, so the window is a plain integer comparison.
        let windowStartKey = ContinuumDay.key(byAdding: -(HabitMath.gridDays - 1), to: todayKey)
        let hasRecentHistory = completed.contains { $0 >= windowStartKey && $0 <= todayKey }
        var result: [PlannedNotification] = []

        for offset in 0..<daysAhead {
            if offset == 0 && doneToday { continue }
            let dayKey = ContinuumDay.key(byAdding: offset, to: todayKey)

            // A day's numbers are only known once every day before it is
            // settled: today always, tomorrow only if today is already done.
            let settled = offset == 0 || (offset == 1 && doneToday)

            let reminderPassed = offset == 0
                && habit.reminderHour * 100 + habit.reminderMinute <= hour * 100 + minute
            if !reminderPassed {
                result.append(PlannedNotification(
                    identifier: NotificationID.reminder(habitId: habit.id, dayKey: dayKey),
                    title: "Time for \(habit.name)",
                    body: settled
                        ? reminderBody(completed: completed, dayKey: dayKey, hasRecentHistory: hasRecentHistory)
                        : pick(neutralLines, dayKey: dayKey),
                    dayKey: dayKey,
                    hour: habit.reminderHour,
                    minute: habit.reminderMinute
                ))
            }

            // Never miss twice: the evening after a miss, when the day before
            // that was done. Tomorrow's is planned while today is still open;
            // marking today (app or widget) removes it.
            let followsOneMiss: Bool
            switch offset {
            case 0:
                followsOneMiss = !completed.contains(yesterdayKey)
                    && completed.contains(ContinuumDay.key(byAdding: -2, to: todayKey))
            case 1:
                followsOneMiss = !doneToday && completed.contains(yesterdayKey)
            case 2:
                // With today done, only tomorrow can go missing before this.
                // Without it, a miss on a day the app isn't opened goes unnoticed.
                followsOneMiss = doneToday
            default:
                followsOneMiss = false
            }
            if followsOneMiss,
               // A reminder from 5pm on already covers the evening; two pings is a nag.
               habit.reminderHour < missAlertHour - 3,
               offset > 0 || hour < missAlertHour {
                result.append(PlannedNotification(
                    identifier: NotificationID.missAlert(habitId: habit.id, dayKey: dayKey),
                    title: "\(habit.name): never miss twice",
                    body: pick([
                        "One miss is a blip. Two is a pattern.",
                        "Yesterday slipped. Tonight's still open.",
                        "Four hours left. One hold does it.",
                    ], dayKey: dayKey),
                    dayKey: dayKey,
                    hour: missAlertHour,
                    minute: 0
                ))
            }
        }
        return result
    }

    /// For days whose numbers aren't known yet.
    private static let neutralLines = [
        "Show up today.",
        "One hold. That's the whole ask.",
        "The grid is waiting.",
    ]

    // Brand voice: dry, confident, zero guilt.
    static func reminderBody(completed: Set<Int>, dayKey: Int, hasRecentHistory: Bool) -> String {
        guard hasRecentHistory else {
            return pick([
                "Day one is waiting.",
                "The grid wants its first mark.",
                "Every habit starts with a single dot.",
            ], dayKey: dayKey)
        }
        if !completed.contains(ContinuumDay.key(byAdding: -1, to: dayKey)) {
            // A miss, but the grid is not empty. No guilt, no "day one".
            return pick([
                "Yesterday's gone. Today's open.",
                "Missed one. Don't miss two.",
                "The grid's still yours. Pick it back up.",
            ], dayKey: dayKey)
        }
        // What today does to the number: the reason to show up, in digits
        let now = HabitMath.consistency(completed: completed, todayKey: dayKey).percent ?? 0
        let ifDone = HabitMath.consistency(completed: completed.union([dayKey]), todayKey: dayKey).percent ?? 0
        guard ifDone > now else {
            return pick([
                "\(now)% consistent. Keep it there.",
                "Still \(now)%. One hold keeps it.",
                "\(now)% of days. Today's one of them.",
            ], dayKey: dayKey)
        }
        return pick([
            "\(now)% consistent. Today makes it \(ifDone).",
            "One hold takes you to \(ifDone)%.",
            "\(ifDone)% is one hold away.",
        ], dayKey: dayKey)
    }

    /// Varies by day but is deterministic, so re-planning doesn't reshuffle text.
    private static func pick(_ lines: [String], dayKey: Int) -> String {
        lines[dayKey % lines.count]
    }
}

// MARK: - Manager

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private var syncChain: Task<Void, Never>?

    private init() {}

    // MARK: Permission

    nonisolated func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    nonisolated func checkPermissionStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: Badge

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    // MARK: Sync

    /// Make the pending queue match `habits` exactly: schedule what's planned,
    /// drop everything else we own (completed days, disabled or deleted habits,
    /// changes synced from another device, pre-3.4 identifiers).
    /// Call after any change to habits, reminders, or completions.
    func sync(habits: [Habit], now: Date = Date()) {
        // Snapshot on the main actor; SwiftData models don't cross actors.
        let calendar = Calendar.current
        let plan = NotificationPlanner.plan(
            for: habits,
            todayKey: ContinuumDay.key(for: now),
            hour: calendar.component(.hour, from: now),
            minute: calendar.component(.minute, from: now)
        )
        // Serialize: two overlapping syncs could otherwise each read the pending
        // list before the other writes, leaving a stale request behind.
        let previous = syncChain
        syncChain = Task {
            await previous?.value
            await Self.apply(plan)
        }
    }

    private nonisolated static func apply(_ plan: [PlannedNotification]) async {
        let center = UNUserNotificationCenter.current()
        let planned = Set(plan.map(\.identifier))
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { NotificationID.isOwned($0) && !planned.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        for item in plan {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default

            // Components without a time zone float with the device, so a
            // 9:00 reminder stays 9:00 local after travel.
            var components = DateComponents()
            components.year = item.dayKey / 10_000
            components.month = item.dayKey / 100 % 100
            components.day = item.dayKey % 100
            components.hour = item.hour
            components.minute = item.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            // Same identifier replaces the pending request, refreshing its text.
            do {
                try await center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
            } catch {
                print("Failed to schedule \(item.identifier): \(error)")
            }
        }
    }
}

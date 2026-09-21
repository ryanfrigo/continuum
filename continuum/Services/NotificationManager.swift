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
    static let streakAlertHour = 20
    static let minimumStreakForAlert = 3
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
        // habit sends, streak alerts included.
        guard habit.reminderEnabled else { return [] }

        let completed = habit.completedDayKeys
        let frozen = habit.frozenDayKeys
        let doneToday = completed.contains(todayKey) || frozen.contains(todayKey)
        let yesterdayKey = ContinuumDay.key(byAdding: -1, to: todayKey)
        // "Day one" copy is only true for an empty grid. A streak of 0 also
        // means "missed yesterday", and a habit with 40 days behind it should
        // never be told it has never started. Day keys are yyyymmdd, so the
        // window is a plain integer comparison.
        let windowStartKey = ContinuumDay.key(byAdding: -(65), to: todayKey)
        let hasRecentHistory = completed.contains { $0 >= windowStartKey && $0 <= todayKey }
            || frozen.contains { $0 >= windowStartKey && $0 <= todayKey }
        var result: [PlannedNotification] = []

        for offset in 0..<daysAhead {
            if offset == 0 && doneToday { continue }
            let dayKey = ContinuumDay.key(byAdding: offset, to: todayKey)

            // The streak riding on a day is only known once every day before it
            // is settled. currentStreak(asOf: today) is 0 until today is marked,
            // which is how 40-day streaks used to get "Day one is waiting."
            let streakAtStake: Int?
            if offset == 0 {
                streakAtStake = HabitMath.currentStreak(completed: completed, frozen: frozen, asOfKey: yesterdayKey)
            } else if offset == 1 && doneToday {
                streakAtStake = HabitMath.currentStreak(completed: completed, frozen: frozen, asOfKey: todayKey)
            } else {
                streakAtStake = nil
            }

            let reminderPassed = offset == 0
                && habit.reminderHour * 100 + habit.reminderMinute <= hour * 100 + minute
            if !reminderPassed {
                result.append(PlannedNotification(
                    identifier: NotificationID.reminder(habitId: habit.id, dayKey: dayKey),
                    title: "Time for \(habit.name)",
                    body: reminderBody(streak: streakAtStake, hasRecentHistory: hasRecentHistory, dayKey: dayKey),
                    dayKey: dayKey,
                    hour: habit.reminderHour,
                    minute: habit.reminderMinute
                ))
            }

            if let streak = streakAtStake,
               streak >= minimumStreakForAlert,
               // A freeze is applied automatically after a missed day, so the
               // streak does not actually end at midnight.
               habit.streakFreezeCount == 0,
               // An evening reminder already covers it; two pings is a nag.
               habit.reminderHour < streakAlertHour,
               offset > 0 || hour < streakAlertHour {
                result.append(PlannedNotification(
                    identifier: NotificationID.streakAlert(habitId: habit.id, dayKey: dayKey),
                    title: "\(streak)-day \(habit.name) streak ends at midnight",
                    body: pick([
                        "A one-second hold keeps it alive.",
                        "Four hours left. You've done harder things.",
                        "\(streak) days of work. One hold protects it.",
                    ], dayKey: dayKey),
                    dayKey: dayKey,
                    hour: streakAlertHour,
                    minute: 0
                ))
            }
        }
        return result
    }

    // Brand voice: dry, confident, zero guilt.
    static func reminderBody(streak: Int?, hasRecentHistory: Bool = false, dayKey: Int) -> String {
        guard let streak else {
            return pick([
                "Show up today.",
                "One hold. That's the whole ask.",
                "The grid is waiting.",
            ], dayKey: dayKey)
        }
        let lines: [String]
        if streak == 0 && hasRecentHistory {
            // The run broke, but the grid is not empty. No guilt, no "day one".
            lines = [
                "Yesterday's gone. Today's open.",
                "Start the next run.",
                "The grid's still yours. Pick it back up.",
            ]
        } else if streak == 0 {
            lines = [
                "Day one is waiting.",
                "The grid wants its first mark.",
                "Every streak starts with a single dot.",
            ]
        } else if streak < 7 {
            lines = [
                "\(streak) down. Show up again today.",
                "\(streak)-day streak. Keep the chain alive.",
                "Day \(streak + 1) is right there.",
            ]
        } else if streak < 21 {
            lines = [
                "\(streak) days strong. Machines don't miss days.",
                "\(streak) days. Momentum is a habit too.",
                "Day \(streak + 1). Showing up is the brand.",
            ]
        } else if streak < 66 {
            lines = [
                "\(streak) days. Only \(66 - streak) to formed.",
                "\(streak)-day streak — the hard part is behind you.",
                "Still perfect at \(streak). Keep it boring.",
            ]
        } else {
            lines = [
                "\(streak) days. This is who you are now.",
                "Day \(streak + 1). Legacy streak.",
                "\(streak) days deep. The habit is you.",
            ]
        }
        return pick(lines, dayKey: dayKey)
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

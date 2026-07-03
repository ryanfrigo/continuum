import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private let daysAhead = 7 // Schedule non-repeating notifications 7 days ahead

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Badge

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    // MARK: - Daily Habit Reminders
    // Uses non-repeating notifications scheduled 7 days ahead.
    // Completed days are skipped. Rescheduled when app becomes active.

    func scheduleNotification(for habit: Habit) {
        // Remove all existing notifications for this habit
        removeNotification(for: habit)

        guard habit.reminderEnabled else { return }

        let today = Calendar.current.startOfDay(for: Date())

        for dayOffset in 0..<daysAhead {
            guard let targetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            // Skip today if already completed
            if dayOffset == 0 && habit.isCompletedToday { continue }

            var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
            dateComponents.hour = habit.reminderHour
            dateComponents.minute = habit.reminderMinute

            // Skip if this time is already past (for today)
            if dayOffset == 0 {
                let now = Date()
                if let triggerDate = Calendar.current.date(from: dateComponents), triggerDate <= now {
                    continue
                }
            }

            let content = UNMutableNotificationContent()
            content.title = "Time for \(habit.name)"
            content.body = getMotivationalMessage(for: habit)
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

            let request = UNNotificationRequest(
                identifier: notificationId(for: habit, dayOffset: dayOffset),
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule notification: \(error)")
                }
            }
        }
    }

    func removeNotification(for habit: Habit) {
        // Remove all day-offset variants
        let ids = (0..<daysAhead).map { notificationId(for: habit, dayOffset: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Remove just today's reminder (e.g., when habit is completed)
    func removeTodayReminder(for habit: Habit) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationId(for: habit, dayOffset: 0)]
        )
    }

    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func rescheduleAllNotifications(habits: [Habit]) {
        removeAllNotifications()
        for habit in habits where habit.reminderEnabled {
            scheduleNotification(for: habit)
        }
    }

    // MARK: - Streak At Risk Notifications

    func scheduleStreakAtRiskNotification(for habit: Habit) {
        removeStreakAtRiskNotification(for: habit)

        // The chain at stake TODAY ends yesterday — currentStreak() counts
        // back from today and is always 0 while today is incomplete, so it
        // can never be used to gate this alert.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let streakAtStakeToday = habit.currentStreak(asOf: yesterday)
        let hour = Calendar.current.component(.hour, from: Date())
        if !habit.isCompletedToday, streakAtStakeToday >= 3, hour < 20 {
            addStreakAtRiskRequest(
                for: habit,
                streak: streakAtStakeToday,
                dayOffset: 0,
                identifier: streakAtRiskNotificationId(for: habit)
            )
        }

        // Tomorrow's alert — the safety net for the day the user never opens
        // the app (today-only scheduling can't fire on the day you forget).
        // The chain at stake tomorrow ends today, so it only exists once
        // today is completed. Replaced or cancelled whenever the app
        // activates or the habit is completed tomorrow.
        let streakAtStakeTomorrow = habit.currentStreak()
        if streakAtStakeTomorrow >= 3 {
            addStreakAtRiskRequest(
                for: habit,
                streak: streakAtStakeTomorrow,
                dayOffset: 1,
                identifier: streakAtRiskNotificationId(for: habit) + "-next"
            )
        }
    }

    private func addStreakAtRiskRequest(for habit: Habit, streak: Int, dayOffset: Int, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(streak)-day \(habit.name) streak ends at midnight"
        content.body = [
            "A one-second hold keeps it alive.",
            "Four hours left. You've done harder things.",
            "\(streak) days of work. One hold protects it.",
        ].randomElement() ?? "A one-second hold keeps it alive."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        guard let targetDay = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) else { return }
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDay)
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule streak-at-risk notification: \(error)")
            }
        }
    }

    func scheduleAllStreakAtRiskNotifications(habits: [Habit]) {
        for habit in habits {
            scheduleStreakAtRiskNotification(for: habit)
        }
    }

    func removeStreakAtRiskNotification(for habit: Habit) {
        let id = streakAtRiskNotificationId(for: habit)
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [id, id + "-next"]
        )
    }

    /// Remove all notifications for a habit (reminders + streak-at-risk)
    func removeAllNotifications(for habit: Habit) {
        removeNotification(for: habit)
        removeStreakAtRiskNotification(for: habit)
    }

    // MARK: - Identifiers

    private func notificationId(for habit: Habit, dayOffset: Int) -> String {
        "habit-reminder-\(habit.id.uuidString)-day\(dayOffset)"
    }

    private func streakAtRiskNotificationId(for habit: Habit) -> String {
        "streak-risk-\(habit.id.uuidString)"
    }

    // MARK: - Message

    private func getMotivationalMessage(for habit: Habit) -> String {
        let streak = habit.currentStreak()

        // Brand voice: dry, confident, zero guilt. Variants keep the 7-day
        // prescheduled batch from reading identically every morning.
        let lines: [String]
        if streak == 0 {
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
                "Day \(streak). Showing up is the brand.",
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
                "Day \(streak). Legacy streak.",
                "\(streak) days deep. The habit is you.",
            ]
        }
        return lines.randomElement() ?? lines[0]
    }
}

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

        let streak = habit.currentStreak()
        guard streak >= 3, !habit.isCompletedToday else { return }

        // Don't schedule if it's already past 8 PM
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour < 20 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your \(streak)-day \(habit.name) streak ends tonight!"
        content.body = "Don't let your progress slip away."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: streakAtRiskNotificationId(for: habit),
            content: content,
            trigger: trigger
        )

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
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [streakAtRiskNotificationId(for: habit)]
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

        if streak == 0 {
            return "Start your streak today!"
        } else if streak < 7 {
            return "You're on a \(streak)-day streak. Keep it going!"
        } else if streak < 21 {
            return "\(streak) days strong. You're building something real."
        } else if streak < 66 {
            return "\(streak)-day streak! You're on your way to forming a habit."
        } else {
            return "\(streak) days. This habit is part of who you are."
        }
    }
}

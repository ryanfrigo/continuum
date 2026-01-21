import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

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

    // MARK: - Scheduling

    func scheduleNotification(for habit: Habit) {
        // Remove any existing notification for this habit
        removeNotification(for: habit)

        guard habit.reminderEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time for \(habit.name)"
        content.body = getMotivationalMessage(for: habit)
        content.sound = .default
        content.badge = 1

        // Create daily trigger at the specified time
        var dateComponents = DateComponents()
        dateComponents.hour = habit.reminderHour
        dateComponents.minute = habit.reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: notificationId(for: habit),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func removeNotification(for habit: Habit) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId(for: habit)])
    }

    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func rescheduleAllNotifications(habits: [Habit]) {
        // Remove all and reschedule
        removeAllNotifications()
        for habit in habits where habit.reminderEnabled {
            scheduleNotification(for: habit)
        }
    }

    // MARK: - Helpers

    private func notificationId(for habit: Habit) -> String {
        "habit-reminder-\(habit.id.uuidString)"
    }

    private func getMotivationalMessage(for habit: Habit) -> String {
        let streak = habit.currentStreak()

        if habit.isCompletedToday {
            return "Already done today! Keep up the great work! 🎉"
        }

        if streak == 0 {
            return "Start your streak today! Every journey begins with a single step."
        } else if streak < 7 {
            return "You're on a \(streak) day streak! Don't break it now!"
        } else if streak < 21 {
            return "\(streak) days strong! You're building something amazing."
        } else if streak < 66 {
            return "Incredible \(streak) day streak! You're on your way to forming a habit."
        } else {
            return "\(streak) days! This habit is part of who you are now."
        }
    }
}

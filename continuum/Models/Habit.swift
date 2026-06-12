import Foundation
import SwiftData

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var completedDates: [Date]?  // Optional to support migration from older versions
    var order: Int?  // Optional to support migration from older versions
    var reminderEnabled: Bool = false
    var reminderHour: Int = 9  // 0-23, default 9am
    var reminderMinute: Int = 0  // 0-59
    var streakFreezeCount: Int = 0  // Available streak freezes
    var freezeUsedDates: [Date]?  // Days where a freeze was used
    var graduatedAt: Date?  // Date when habit hit 66 days (nil if not yet graduated)

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), completedDates: [Date] = [], order: Int? = nil, reminderEnabled: Bool = false, reminderHour: Int = 9, reminderMinute: Int = 0) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.completedDates = completedDates.map { Habit.startOfDay($0) }
        self.order = order
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.streakFreezeCount = 0
        self.freezeUsedDates = nil
        self.graduatedAt = nil
    }

    // Computed property to always return a non-nil completedDates array
    var completedDatesArray: [Date] {
        get { completedDates ?? [] }
        set { completedDates = newValue }
    }

    /// Returns the reminder time as a Date (for DatePicker binding)
    var reminderTime: Date {
        get {
            var components = DateComponents()
            components.hour = reminderHour
            components.minute = reminderMinute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = components.hour ?? 9
            reminderMinute = components.minute ?? 0
        }
    }
    
    // Computed property to always return a non-nil order value
    var orderValue: Int {
        get { order ?? 0 }
        set { order = newValue }
    }

    // MARK: - Helpers

    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private var completedSet: Set<Date> {
        Set(completedDatesArray.map { Habit.startOfDay($0) })
    }

    var isCompletedToday: Bool {
        let today = Habit.startOfDay(Date())
        return completedSet.contains(today)
    }

    func toggleCompletion(for date: Date = Date()) {
        let day = Habit.startOfDay(date)
        var dates = completedDatesArray
        if let idx = dates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: day) }) {
            dates.remove(at: idx)
        } else {
            dates.append(day)
        }
        completedDatesArray = dates
    }

    func currentStreak(asOf date: Date = Date()) -> Int {
        let set = completedSet
        var count = 0
        var cursor = Habit.startOfDay(date)
        while set.contains(cursor) {
            count += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = Habit.startOfDay(prev)
        }
        return count
    }

    /// Returns the start date of the current streak, or nil if no streak
    func streakStartDate(asOf date: Date = Date()) -> Date? {
        let set = completedSet
        var cursor = Habit.startOfDay(date)
        var streakStart: Date? = nil

        while set.contains(cursor) {
            streakStart = cursor
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = Habit.startOfDay(prev)
        }
        return streakStart
    }

    /// Returns the habit health as a percentage of the last 66 days completed (0.0 to 1.0)
    func habitHealth(asOf date: Date = Date()) -> Double {
        let daysBack = 66
        let set = completedSet
        let start = Habit.startOfDay(date)
        var completedCount = 0

        for offset in 0..<daysBack {
            if let d = Calendar.current.date(byAdding: .day, value: -offset, to: start) {
                if set.contains(Habit.startOfDay(d)) {
                    completedCount += 1
                }
            }
        }

        return Double(completedCount) / Double(daysBack)
    }

    func historyCompletionFlags(daysBack: Int = 66, asOf date: Date = Date()) -> [Bool] {
        let set = completedSet
        let start = Habit.startOfDay(date)
        return (0..<daysBack).reversed().map { offset in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: start) ?? start
            return set.contains(Habit.startOfDay(d))
        }
    }

    // MARK: - Streak Freeze

    var freezeUsedDatesArray: [Date] {
        get { freezeUsedDates ?? [] }
        set { freezeUsedDates = newValue }
    }

    private var freezeUsedSet: Set<Date> {
        Set(freezeUsedDatesArray.map { Habit.startOfDay($0) })
    }

    /// Whether a streak freeze was used for yesterday (protecting today's streak)
    var isFreezeActiveToday: Bool {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Habit.startOfDay(Date())) ?? Date()
        return freezeUsedSet.contains(Habit.startOfDay(yesterday))
    }

    /// Use a streak freeze for yesterday (call when user opens app and yesterday was missed)
    /// Returns true if freeze was successfully applied
    @discardableResult
    func useStreakFreeze() -> Bool {
        guard streakFreezeCount > 0 else { return false }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Habit.startOfDay(Date())) ?? Date()
        let yesterdayStart = Habit.startOfDay(yesterday)

        // Don't freeze if yesterday was completed or already frozen
        guard !completedSet.contains(yesterdayStart),
              !freezeUsedSet.contains(yesterdayStart) else { return false }

        streakFreezeCount -= 1
        freezeUsedDatesArray.append(yesterdayStart)
        return true
    }

    /// Grant a streak freeze (earned weekly or at milestones)
    func grantStreakFreeze(count: Int = 1) {
        streakFreezeCount = min(streakFreezeCount + count, 3) // Max 3 stored
    }

    /// Current streak counting freeze days as "completed"
    func currentStreakWithFreezes(asOf date: Date = Date()) -> Int {
        let completed = completedSet
        let frozen = freezeUsedSet
        var count = 0
        var cursor = Habit.startOfDay(date)
        while completed.contains(cursor) || frozen.contains(cursor) {
            count += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = Habit.startOfDay(prev)
        }
        return count
    }

    /// Whether this habit has been "graduated" (completed 66-day streak)
    var isGraduated: Bool {
        graduatedAt != nil
    }

    /// Mark as graduated if streak >= 66 and not already graduated
    func checkAndMarkGraduation() -> Bool {
        guard graduatedAt == nil, currentStreak() >= 66 else { return false }
        graduatedAt = Date()
        return true
    }

    // MARK: - Mutations

    /// Remove all completion history.
    func resetProgress() {
        completedDatesArray = []
        graduatedAt = nil
    }

    /// Mark the most recent `count` days (including today) as completed.
    /// If a day is already marked complete it will not be duplicated.
    func addRecentDays(_ count: Int, asOf date: Date = Date()) {
        guard count > 0 else { return }
        let base = Habit.startOfDay(date)
        var dates = completedDatesArray
        for delta in 0..<count {
            if let d = Calendar.current.date(byAdding: .day, value: -delta, to: base) {
                let day = Habit.startOfDay(d)
                if !completedSet.contains(day) {
                    dates.append(day)
                }
            }
        }
        completedDatesArray = dates
    }

    /// Force the current streak (ending today) to be exactly `target` days long.
    /// This ensures all days in the last `target`-1 offsets are completed, and the
    /// day at offset `target` is cleared to break any longer chain.
    func setCurrentStreak(_ target: Int, asOf date: Date = Date()) {
        let clamped = max(0, min(1000, target))
        let today = Habit.startOfDay(date)
        var dates = completedDatesArray

        // Ensure the last `clamped` days (including today) are completed
        if clamped > 0 {
            for delta in 0..<clamped {
                if let d = Calendar.current.date(byAdding: .day, value: -delta, to: today) {
                    let day = Habit.startOfDay(d)
                    if !completedSet.contains(day) {
                        dates.append(day)
                    }
                }
            }
        } else {
            // clamped == 0: make sure today is not completed
            if let idx = dates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
                dates.remove(at: idx)
            }
        }

        // Break any longer chain by ensuring the day just before the earliest streak day is not completed
        if let breakDay = Calendar.current.date(byAdding: .day, value: -clamped, to: today) {
            let bd = Habit.startOfDay(breakDay)
            if let idx = dates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: bd) }) {
                dates.remove(at: idx)
            }
        }

        completedDatesArray = dates
    }
}







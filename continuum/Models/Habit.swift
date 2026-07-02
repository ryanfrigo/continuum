import Foundation
import SwiftData

// NOTE on CloudKit compatibility:
// - No `@Attribute(.unique)` (CloudKit does not support unique constraints;
//   duplicates from sync are merged by ContentView.dedupeHabits()).
// - Every non-optional property has a default value.
// All day storage is canonical noon-UTC (see ContinuumDay in Shared/).
@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
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
        self.completedDates = completedDates.map { ContinuumDay.storageDate(for: ContinuumDay.key(forStorage: $0)) }
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

    /// Start of day for a LIVE date in the user's calendar (UI alignment only —
    /// never used for storage).
    static func startOfDay(_ date: Date) -> Date {
        ContinuumDay.calendar.startOfDay(for: date)
    }

    /// Day keys of all completed days (canonical, timezone-safe).
    var completedDayKeys: Set<Int> {
        ContinuumDay.keys(fromStorage: completedDatesArray)
    }

    /// Day keys of all freeze-used days.
    var frozenDayKeys: Set<Int> {
        ContinuumDay.keys(fromStorage: freezeUsedDatesArray)
    }

    var isCompletedToday: Bool {
        completedDayKeys.contains(ContinuumDay.todayKey())
    }

    /// Whether the habit was completed on the given (live) date.
    func isCompleted(on date: Date) -> Bool {
        completedDayKeys.contains(ContinuumDay.key(for: date))
    }

    /// Whether a streak freeze was used on the given (live) date.
    func wasFrozen(on date: Date) -> Bool {
        frozenDayKeys.contains(ContinuumDay.key(for: date))
    }

    func toggleCompletion(for date: Date = Date()) {
        setCompleted(!isCompleted(on: date), on: date)
    }

    /// Set the completion state for a specific (live) date.
    func setCompleted(_ completed: Bool, on date: Date) {
        setCompleted(completed, forDayKey: ContinuumDay.key(for: date))
    }

    /// Set the completion state for a specific day key.
    func setCompleted(_ completed: Bool, forDayKey key: Int) {
        var keys = completedDayKeys
        if completed {
            guard !keys.contains(key) else { return }
            keys.insert(key)
        } else {
            guard keys.contains(key) else { return }
            keys.remove(key)
        }
        completedDatesArray = keys.sorted().map { ContinuumDay.storageDate(for: $0) }
    }

    /// Current streak ending on `date`. Frozen days bridge AND count, so a
    /// used streak freeze actually preserves the streak the user sees.
    func currentStreak(asOf date: Date = Date()) -> Int {
        HabitMath.currentStreak(
            completed: completedDayKeys,
            frozen: frozenDayKeys,
            asOfKey: ContinuumDay.key(for: date)
        )
    }

    /// Longest streak anywhere in history.
    func longestStreak() -> Int {
        HabitMath.longestStreak(completed: completedDayKeys, frozen: frozenDayKeys)
    }

    /// Returns the start date of the current streak, or nil if no streak
    func streakStartDate(asOf date: Date = Date()) -> Date? {
        let streak = currentStreak(asOf: date)
        guard streak > 0 else { return nil }
        let startKey = ContinuumDay.key(byAdding: -(streak - 1), to: ContinuumDay.key(for: date))
        return ContinuumDay.storageDate(for: startKey)
    }

    /// Returns the habit health as a percentage of the last 66 days completed (0.0 to 1.0)
    func habitHealth(asOf date: Date = Date()) -> Double {
        HabitMath.health(completed: completedDayKeys, asOfKey: ContinuumDay.key(for: date))
    }

    func historyCompletionFlags(daysBack: Int = 66, asOf date: Date = Date()) -> [Bool] {
        HabitMath.historyFlags(
            completed: completedDayKeys,
            asOfKey: ContinuumDay.key(for: date),
            daysBack: daysBack
        )
    }

    // MARK: - Streak Freeze

    var freezeUsedDatesArray: [Date] {
        get { freezeUsedDates ?? [] }
        set { freezeUsedDates = newValue }
    }

    /// Whether a streak freeze was used for yesterday (protecting today's streak)
    var isFreezeActiveToday: Bool {
        frozenDayKeys.contains(ContinuumDay.key(byAdding: -1, to: ContinuumDay.todayKey()))
    }

    /// Use a streak freeze for yesterday (call when user opens app and yesterday was missed)
    /// Returns true if freeze was successfully applied
    @discardableResult
    func useStreakFreeze() -> Bool {
        guard streakFreezeCount > 0 else { return false }
        let yesterdayKey = ContinuumDay.key(byAdding: -1, to: ContinuumDay.todayKey())

        // Don't freeze if yesterday was completed or already frozen
        guard !completedDayKeys.contains(yesterdayKey),
              !frozenDayKeys.contains(yesterdayKey) else { return false }

        streakFreezeCount -= 1
        var keys = frozenDayKeys
        keys.insert(yesterdayKey)
        freezeUsedDatesArray = keys.sorted().map { ContinuumDay.storageDate(for: $0) }
        return true
    }

    /// Grant a streak freeze (earned weekly or at milestones)
    func grantStreakFreeze(count: Int = 1) {
        streakFreezeCount = min(streakFreezeCount + count, 3) // Max 3 stored
    }

    /// Current streak counting freeze days as "completed".
    /// (Now identical to `currentStreak` — kept for API compatibility.)
    func currentStreakWithFreezes(asOf date: Date = Date()) -> Int {
        currentStreak(asOf: date)
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

    // MARK: - Migration

    /// Rewrites any legacy (midnight-local) stored dates into canonical
    /// noon-UTC form. Idempotent and cheap — safe to call on every launch.
    /// Returns true if anything changed.
    @discardableResult
    func migrateToCanonicalStorage() -> Bool {
        var changed = false

        let completed = completedDatesArray
        if completed.contains(where: { !ContinuumDay.isCanonical($0) }) {
            completedDatesArray = ContinuumDay.keys(fromStorage: completed)
                .sorted()
                .map { ContinuumDay.storageDate(for: $0) }
            changed = true
        }

        let frozen = freezeUsedDatesArray
        if !frozen.isEmpty, frozen.contains(where: { !ContinuumDay.isCanonical($0) }) {
            freezeUsedDatesArray = ContinuumDay.keys(fromStorage: frozen)
                .sorted()
                .map { ContinuumDay.storageDate(for: $0) }
            changed = true
        }

        return changed
    }

    /// Absorb a CloudKit-sync duplicate of this habit (same `id`), merging
    /// histories so no completions are lost. Caller deletes the duplicate.
    func absorb(_ other: Habit) {
        let mergedCompleted = completedDayKeys.union(other.completedDayKeys)
        completedDatesArray = mergedCompleted.sorted().map { ContinuumDay.storageDate(for: $0) }

        let mergedFrozen = frozenDayKeys.union(other.frozenDayKeys)
        if !mergedFrozen.isEmpty {
            freezeUsedDatesArray = mergedFrozen.sorted().map { ContinuumDay.storageDate(for: $0) }
        }

        streakFreezeCount = max(streakFreezeCount, other.streakFreezeCount)
        createdAt = min(createdAt, other.createdAt)
        if graduatedAt == nil { graduatedAt = other.graduatedAt }
        if let otherOrder = other.order {
            order = min(order ?? otherOrder, otherOrder)
        }
    }

    // MARK: - Mutations

    /// Remove all completion history.
    func resetProgress() {
        completedDatesArray = []
        freezeUsedDates = nil
        graduatedAt = nil
    }

    /// Mark the most recent `count` days (including today) as completed.
    /// If a day is already marked complete it will not be duplicated.
    func addRecentDays(_ count: Int, asOf date: Date = Date()) {
        guard count > 0 else { return }
        let base = ContinuumDay.key(for: date)
        var keys = completedDayKeys
        for delta in 0..<count {
            keys.insert(ContinuumDay.key(byAdding: -delta, to: base))
        }
        completedDatesArray = keys.sorted().map { ContinuumDay.storageDate(for: $0) }
    }

    /// Force the current streak (ending today) to be exactly `target` days long.
    /// This ensures all days in the last `target`-1 offsets are completed, and the
    /// day at offset `target` is cleared to break any longer chain.
    func setCurrentStreak(_ target: Int, asOf date: Date = Date()) {
        let clamped = max(0, min(1000, target))
        let todayKey = ContinuumDay.key(for: date)
        var keys = completedDayKeys

        if clamped > 0 {
            for delta in 0..<clamped {
                keys.insert(ContinuumDay.key(byAdding: -delta, to: todayKey))
            }
        } else {
            // clamped == 0: make sure today is not completed
            keys.remove(todayKey)
        }

        // Break any longer chain by clearing the day just before the streak start
        keys.remove(ContinuumDay.key(byAdding: -clamped, to: todayKey))

        completedDatesArray = keys.sorted().map { ContinuumDay.storageDate(for: $0) }
    }
}

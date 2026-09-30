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
    var streakFreezeCount: Int = 0  // Retired in 3.8; kept because CloudKit fields can't be removed
    var freezeUsedDates: [Date]?  // Days where a freeze was used
    var graduatedAt: Date?  // Date the habit was formed (nil until then)

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
            keys.insert(key)
        } else {
            keys.remove(key)
        }
        setCompletedKeys(keys)
    }

    /// The single write path for user edits to completion history: updates the
    /// working array and records each changed day in the per-day sync ledger
    /// (see CompletionMark). Writing the array directly would sync
    /// last-writer-wins and be overruled by the ledger on the next reconcile.
    func setCompletedKeys(_ newKeys: Set<Int>) {
        let oldKeys = completedDayKeys
        guard newKeys != oldKeys else { return }
        completedDatesArray = newKeys.sorted().map { ContinuumDay.storageDate(for: $0) }

        // A habit not yet inserted has nothing to sync; reconcile imports its days later.
        guard let context = modelContext else { return }
        let habitId = id
        let now = Date()
        // One fetch for the habit, not one per day: reset or set-streak can touch hundreds
        let existing = (try? context.fetch(FetchDescriptor<CompletionMark>(
            predicate: #Predicate { $0.habitId == habitId }
        ))) ?? []
        let markByDay = Dictionary(existing.map { ($0.dayKey, $0) }, uniquingKeysWith: { a, _ in a })
        for key in newKeys.symmetricDifference(oldKeys) {
            let completed = newKeys.contains(key)
            // Update the existing mark in place so repeated toggles don't pile up records
            if let mark = markByDay[key] {
                mark.isCompleted = completed
                mark.modifiedAt = now
            } else {
                context.insert(CompletionMark(habitId: habitId, dayKey: key, isCompleted: completed, modifiedAt: now))
            }
        }
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

    /// The streak to SHOW. `currentStreak()` counts back from today and so
    /// reads 0 until today is marked — displaying it blanks out a live streak
    /// every morning. Shown as the current run on the stats screen.
    var displayStreak: Int {
        if isCompletedToday { return currentStreak() }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return currentStreak(asOf: yesterday)
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

    /// Consistency as every screen shows it (see HabitMath.tally).
    var consistency: ConsistencyTally {
        HabitMath.consistency(completed: completedDayKeys, todayKey: ContinuumDay.todayKey())
    }

    /// Change in the shown percentage over the last 7 days; nil while too new.
    var consistencyTrend: Int? {
        let keys = completedDayKeys
        let today = ContinuumDay.todayKey()
        return HabitMath.trend(now: HabitMath.consistency(completed: keys, todayKey: today),
                               weekAgo: HabitMath.consistencyWeekAgo(completed: keys, todayKey: today))
    }

    /// Every day ever marked done. Only goes up; a bad week can't take one back.
    var daysDone: Int { completedDayKeys.count }

    func historyCompletionFlags(daysBack: Int = 66, asOf date: Date = Date()) -> [Bool] {
        HabitMath.historyFlags(
            completed: completedDayKeys,
            asOfKey: ContinuumDay.key(for: date),
            daysBack: daysBack
        )
    }

    // MARK: - Streak Freeze (retired in 3.8)
    // Nothing grants or spends freezes any more. Days frozen before 3.8 still
    // bridge a run, and count as missed for consistency — they were.

    var freezeUsedDatesArray: [Date] {
        get { freezeUsedDates ?? [] }
        set { freezeUsedDates = newValue }
    }

    // MARK: - Graduation

    /// Whether this habit has been "graduated": formed, and it stays formed
    var isGraduated: Bool {
        graduatedAt != nil
    }

    /// Mark as formed once it's 66 days in with 80% of them done
    func checkAndMarkGraduation() -> Bool {
        guard graduatedAt == nil,
              HabitMath.isFormed(completed: completedDayKeys, todayKey: ContinuumDay.todayKey())
        else { return false }
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
    /// Writes the array directly on purpose: both copies share one ledger, and
    /// fresh marks here would outrank real un-completions from other devices.
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
        setCompletedKeys([])
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
        setCompletedKeys(keys)
    }

    /// Force the current streak (ending today) to be exactly `target` days long.
    /// This ensures all days in the last `target`-1 offsets are completed, and the
    /// two days before the streak are cleared — one miss is a grace day, two
    /// break the chain.
    func setCurrentStreak(_ target: Int, asOf date: Date = Date()) {
        let clamped = max(0, min(1000, target))
        let todayKey = ContinuumDay.key(for: date)
        var keys = completedDayKeys

        for delta in 0..<clamped {
            keys.insert(ContinuumDay.key(byAdding: -delta, to: todayKey))
        }

        // Break any longer chain: two misses in a row, grace can't bridge them
        keys.remove(ContinuumDay.key(byAdding: -clamped, to: todayKey))
        keys.remove(ContinuumDay.key(byAdding: -(clamped + 1), to: todayKey))

        setCompletedKeys(keys)
    }
}

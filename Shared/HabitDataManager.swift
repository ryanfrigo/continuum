import Foundation
import WidgetKit
#if !WIDGET_EXTENSION
import SwiftData
#endif

// MARK: - Canonical Day Handling (timezone-safe)
//
// PROBLEM: Continuum used to store completed days as `Calendar.current.startOfDay`
// timestamps. A midnight timestamp saved in one timezone can resolve to a
// DIFFERENT calendar day when read in another timezone (e.g. complete a habit
// in New York, fly to Honolulu, and every history dot shifts back a day —
// silently breaking streaks).
//
// FIX: A calendar day is now canonically encoded as *12:00:30 UTC* of that
// day. The encoding/decoding below never relies on the device timezone for
// canonical dates, so reads are exact in ALL timezones.
//
// Why :30 seconds? Canonical dates are told apart from legacy ones by shape,
// and legacy dates are `startOfDay` in SOME timezone. Every real UTC offset
// is a whole number of minutes, so a legacy midnight always has seconds == 0
// — plain noon UTC would collide with local midnight in UTC+12 zones (NZST,
// Fiji) and misread that entire history by a day. Seconds == 30 cannot be
// produced by any startOfDay, making detection unambiguous.
//
// - "Live" dates (now, picker selections) are interpreted in the user's
//   current calendar to produce a day key like 20260612.
// - Day keys are persisted as canonical Dates (backwards compatible with the
//   existing `[Date]` storage and widget JSON).
// - Legacy midnight-local dates are detected and interpreted with the old
//   behavior, then migrated to canonical form on launch (see Habit migration).
enum ContinuumDay {

    /// Calendar used to interpret "live" dates (defaults to the user's).
    /// Overridable in unit tests to simulate timezone changes.
    static var calendar: Calendar = .current

    /// Fixed UTC calendar used for canonical storage math.
    static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    // MARK: Day keys (yyyymmdd as Int)

    /// Day key for a live date (e.g. `Date()`), interpreted in the user's calendar.
    static func key(for date: Date, calendar: Calendar? = nil) -> Int {
        let cal = calendar ?? ContinuumDay.calendar
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 1970) * 10_000 + (c.month ?? 1) * 100 + (c.day ?? 1)
    }

    /// Today's day key in the user's calendar.
    static func todayKey() -> Int {
        key(for: Date())
    }

    /// Canonical storage Date (12:00:30 UTC) for a day key.
    static func storageDate(for key: Int) -> Date {
        var c = DateComponents()
        c.year = key / 10_000
        c.month = (key / 100) % 100
        c.day = key % 100
        c.hour = 12
        c.second = 30
        return utcCalendar.date(from: c) ?? Date(timeIntervalSince1970: 0)
    }

    /// Whether a stored Date is already in canonical (12:00:30 UTC) form.
    /// The :30 seconds is the marker — no timezone's `startOfDay` can produce
    /// it, so legacy midnight-local dates (including UTC+12 zones, where local
    /// midnight is exactly noon UTC of the previous day) are never mistaken
    /// for canonical dates.
    static func isCanonical(_ stored: Date) -> Bool {
        let c = utcCalendar.dateComponents([.hour, .minute, .second], from: stored)
        return c.hour == 12 && c.minute == 0 && c.second == 30
    }

    /// Day key for a STORED date.
    /// Canonical dates are read in UTC — exact in every timezone.
    /// Legacy dates fall back to the old behavior (current calendar).
    static func key(forStorage stored: Date) -> Int {
        if isCanonical(stored) {
            let c = utcCalendar.dateComponents([.year, .month, .day], from: stored)
            return (c.year ?? 1970) * 10_000 + (c.month ?? 1) * 100 + (c.day ?? 1)
        }
        return key(for: stored)
    }

    /// Day-key set for an array of stored dates.
    static func keys(fromStorage dates: [Date]) -> Set<Int> {
        Set(dates.map { key(forStorage: $0) })
    }

    /// Step a day key by N calendar days (handles month/year boundaries).
    static func key(byAdding days: Int, to key: Int) -> Int {
        guard let d = utcCalendar.date(byAdding: .day, value: days, to: storageDate(for: key)) else { return key }
        let c = utcCalendar.dateComponents([.year, .month, .day], from: d)
        return (c.year ?? 1970) * 10_000 + (c.month ?? 1) * 100 + (c.day ?? 1)
    }

    /// Weekday (1 = Sunday ... 7 = Saturday) of a day key.
    /// A calendar date's weekday is timezone-independent.
    static func weekday(of key: Int) -> Int {
        utcCalendar.component(.weekday, from: storageDate(for: key))
    }

    /// Number of calendar days from `from` to `to` (positive if `to` is later).
    static func daysBetween(_ from: Int, _ to: Int) -> Int {
        utcCalendar.dateComponents(
            [.day],
            from: storageDate(for: from),
            to: storageDate(for: to)
        ).day ?? 0
    }
}

// MARK: - Consistency
// The number the app is about: of the days a habit has been going, the share
// you showed up. Pure and shared, so the app and the widget always agree.

/// Days shown up over days counted.
struct ConsistencyTally: Equatable {
    var done = 0
    var counted = 0

    /// Whole percent, rounded down so an imperfect record never reads 100.
    /// Nil until a day has been counted.
    var percent: Int? { counted > 0 ? done * 100 / counted : nil }

    /// 0...1 for colours and rings; 0 until a day has been counted.
    var fraction: Double { counted > 0 ? Double(done) / Double(counted) : 0 }

    static func + (a: ConsistencyTally, b: ConsistencyTally) -> ConsistencyTally {
        ConsistencyTally(done: a.done + b.done, counted: a.counted + b.counted)
    }
}

// MARK: - Streak / history math over day keys
// Shared between Habit (app) and HabitData (widget) so both always agree.
enum HabitMath {

    /// Days on the card's grid, and the window consistency is measured over.
    static let gridDays = 66
    /// Days done, in any order, that form a habit.
    static let daysToForm = 66

    /// Consistency over the `window` days ending at `endKey`, counted from the
    /// first completed day — a habit added Monday and started Thursday isn't
    /// three days behind. With `endInProgress`, the end day counts only once
    /// it's done: a day that isn't over isn't a miss yet.
    static func tally(completed: Set<Int>, endKey: Int, window: Int = gridDays, endInProgress: Bool) -> ConsistencyTally {
        guard window > 0, let first = completed.min(), first <= endKey else { return ConsistencyTally() }
        // Day keys are yyyymmdd, so plain integer comparison orders them
        let start = max(first, ContinuumDay.key(byAdding: -(window - 1), to: endKey))
        var counted = ContinuumDay.daysBetween(start, endKey) + 1
        if endInProgress && !completed.contains(endKey) { counted -= 1 }
        let done = completed.filter { $0 >= start && $0 <= endKey }.count
        return ConsistencyTally(done: done, counted: counted)
    }

    /// The number every screen shows: the grid window, today counting once done.
    static func consistency(completed: Set<Int>, todayKey: Int) -> ConsistencyTally {
        tally(completed: completed, endKey: todayKey, endInProgress: true)
    }

    /// The same number as it stood a week ago, that whole day counted.
    static func consistencyWeekAgo(completed: Set<Int>, todayKey: Int) -> ConsistencyTally {
        tally(completed: completed, endKey: ContinuumDay.key(byAdding: -7, to: todayKey), endInProgress: false)
    }

    /// Change in the shown percentage over 7 days. Nil until the week-ago
    /// number had 7 counted days behind it; before that it's noise.
    static func trend(now: ConsistencyTally, weekAgo: ConsistencyTally) -> Int? {
        guard weekAgo.counted >= 7, let a = now.percent, let b = weekAgo.percent else { return nil }
        return a - b
    }

    /// Every day since the first completion, today counting once done.
    static func allTime(completed: Set<Int>, todayKey: Int) -> ConsistencyTally {
        guard let first = completed.min(), first <= todayKey else { return ConsistencyTally() }
        let window = ContinuumDay.daysBetween(first, todayKey) + 1
        return tally(completed: completed, endKey: todayKey, window: window, endInProgress: true)
    }

    /// Consecutive 7-day blocks, oldest first, the last ending today (today
    /// counting once done). Empty before the habit's first day.
    static func weeklyBlocks(completed: Set<Int>, todayKey: Int, weeks: Int) -> [ConsistencyTally] {
        (0..<weeks).reversed().map { back in
            tally(completed: completed,
                  endKey: ContinuumDay.key(byAdding: -7 * back, to: todayKey),
                  window: 7,
                  endInProgress: back == 0)
        }
    }

    /// Days missed right before `dayKey`, if marking it is a comeback: done,
    /// the day before missed, and 3+ days done before the gap, so there's a
    /// rhythm to come back to. Nil otherwise.
    static func comebackGap(completed: Set<Int>, dayKey: Int) -> Int? {
        let dayBefore = ContinuumDay.key(byAdding: -1, to: dayKey)
        guard completed.contains(dayKey), !completed.contains(dayBefore) else { return nil }
        let prior = completed.filter { $0 < dayBefore }
        guard prior.count >= 3, let last = prior.max() else { return nil }
        return ContinuumDay.daysBetween(last, dayKey) - 1
    }

    /// Minimum spacing between grace days: one missed day per week is forgiven.
    static let graceSpacingDays = 7

    /// Current streak ending at `asOfKey` — "never miss twice". Completed and
    /// frozen days count. A single missed day bridges the run without counting,
    /// as long as the day before it counts and no other grace day falls within
    /// `graceSpacingDays` of it; two misses in a row end the run.
    ///
    /// A miss AT `asOfKey` is a grace day too, so the result reads "the streak
    /// that survives if the next day is done" — which is what the UI shows
    /// before today is marked.
    static func currentStreak(completed: Set<Int>, frozen: Set<Int>, asOfKey: Int) -> Int {
        var count = 0
        var cursor = asOfKey
        var step = 0
        var lastGraceStep: Int?
        while true {
            if completed.contains(cursor) || frozen.contains(cursor) {
                count += 1
            } else {
                let previous = ContinuumDay.key(byAdding: -1, to: cursor)
                let spaced = lastGraceStep.map { step - $0 >= graceSpacingDays } ?? true
                guard spaced, completed.contains(previous) || frozen.contains(previous) else { break }
                lastGraceStep = step
            }
            cursor = ContinuumDay.key(byAdding: -1, to: cursor)
            step += 1
        }
        return count
    }

    /// Longest streak anywhere in history, by the same rule as `currentStreak`.
    static func longestStreak(completed: Set<Int>, frozen: Set<Int>) -> Int {
        let all = completed.union(frozen)
        // Only a day that ends a run can end the longest one
        return all
            .filter { !all.contains(ContinuumDay.key(byAdding: 1, to: $0)) }
            .map { currentStreak(completed: completed, frozen: frozen, asOfKey: $0) }
            .max() ?? 0
    }

    /// Consecutive "perfect days" ending at `asOfKey`. A day is perfect when
    /// every habit that already existed on that day completed it. Days before
    /// the first habit existed end the run.
    static func consecutivePerfectDays(habits: [(completed: Set<Int>, createdKey: Int)], asOfKey: Int) -> Int {
        guard !habits.isEmpty else { return 0 }
        var count = 0
        var cursor = asOfKey
        while true {
            let active = habits.filter { $0.createdKey <= cursor }
            guard !active.isEmpty,
                  active.allSatisfy({ $0.completed.contains(cursor) }) else { break }
            count += 1
            cursor = ContinuumDay.key(byAdding: -1, to: cursor)
        }
        return count
    }

    /// Oldest-first completion flags for the last `daysBack` days ending at `asOfKey`.
    static func historyFlags(completed: Set<Int>, asOfKey: Int, daysBack: Int) -> [Bool] {
        var flags: [Bool] = []
        flags.reserveCapacity(daysBack)
        var cursor = ContinuumDay.key(byAdding: -(daysBack - 1), to: asOfKey)
        for _ in 0..<daysBack {
            flags.append(completed.contains(cursor))
            cursor = ContinuumDay.key(byAdding: 1, to: cursor)
        }
        return flags
    }
}

// MARK: - Notification Identifiers
// Shared so the widget can cancel exactly what the app scheduled. Keyed by
// calendar day: an offset ("day0") is relative to whenever the app last ran,
// so the widget could never tell which request was today's.
enum NotificationID {
    static let reminderPrefix = "habit-reminder-"
    /// The evening never-miss-twice alert. The prefix is the old streak
    /// alert's, kept so requests left pending by 3.7 are still recognized.
    static let missAlertPrefix = "streak-risk-"

    static func reminder(habitId: UUID, dayKey: Int) -> String {
        "\(reminderPrefix)\(habitId.uuidString)-\(dayKey)"
    }

    static func missAlert(habitId: UUID, dayKey: Int) -> String {
        "\(missAlertPrefix)\(habitId.uuidString)-\(dayKey)"
    }

    /// Everything the app has ever scheduled, including pre-3.4 offset-style IDs.
    static func isOwned(_ identifier: String) -> Bool {
        identifier.hasPrefix(reminderPrefix) || identifier.hasPrefix(missAlertPrefix)
    }
}

// MARK: - Pending Widget Toggles
// The interactive widget can't write to SwiftData directly, so it updates the
// shared JSON optimistically AND records the desired end state here. The app
// drains this queue on activation and reconciles SwiftData.
struct PendingHabitToggle: Codable {
    let habitId: UUID
    let dayKey: Int
    let completed: Bool   // desired end state for that day
    let timestamp: Date
}

class HabitDataManager {
    static let shared = HabitDataManager()
    static let appGroupIdentifier = "group.com.orionlabs.continuum"

    private static let pendingTogglesKey = "pendingWidgetToggles"

    private init() {}

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    // MARK: - Data Persistence

    func saveSelectedHabitId(_ habitId: UUID?) {
        if let habitId = habitId {
            defaults?.set(habitId.uuidString, forKey: "selectedHabitId")
        } else {
            defaults?.removeObject(forKey: "selectedHabitId")
        }
    }

    func getSelectedHabitId() -> UUID? {
        guard let habitIdString = defaults?.string(forKey: "selectedHabitId") else {
            return nil
        }
        return UUID(uuidString: habitIdString)
    }

    // MARK: - Widget Timeline Updates

    func updateWidgetTimeline() {
        WidgetCenter.shared.reloadTimelines(ofKind: "continuumWidget")
    }

    // MARK: - Habit Data Access

    func getAllHabitIds() -> [UUID] {
        guard let data = defaults?.data(forKey: "allHabitIds") else {
            return []
        }
        do {
            let ids = try JSONDecoder().decode([String].self, from: data)
            return ids.compactMap { UUID(uuidString: $0) }
        } catch {
            return []
        }
    }

    func saveAllHabitIds(_ habitIds: [UUID]) {
        let ids = habitIds.map { $0.uuidString }
        do {
            let data = try JSONEncoder().encode(ids)
            defaults?.set(data, forKey: "allHabitIds")
        } catch {
            print("Failed to encode habit IDs: \(error)")
        }
    }

    func getSelectedHabitData() -> HabitData? {
        // First try to get a selected habit
        if let habitId = getSelectedHabitId(),
           let habitData = getHabitData(for: habitId) {
            return habitData
        }

        // Otherwise, get the first habit by order
        let allIds = getAllHabitIds()
        for habitId in allIds {
            if let habitData = getHabitData(for: habitId) {
                return habitData
            }
        }

        return nil
    }

    func getHabitData(for habitId: UUID) -> HabitData? {
        guard let data = defaults?.data(forKey: "habitData_\(habitId.uuidString)") else {
            return nil
        }

        do {
            let habitData = try JSONDecoder().decode(HabitData.self, from: data)
            return habitData
        } catch {
            print("Failed to decode habit data: \(error)")
            return nil
        }
    }

    func saveHabitData(_ habitData: HabitData) {
        do {
            let data = try JSONEncoder().encode(habitData)
            defaults?.set(data, forKey: "habitData_\(habitData.id.uuidString)")
        } catch {
            print("Failed to encode habit data: \(error)")
        }
    }

    func removeHabitData(for habitId: UUID) {
        defaults?.removeObject(forKey: "habitData_\(habitId.uuidString)")
    }

    // MARK: - Widget Helper Methods

    func loadAllHabitData() -> [HabitData] {
        let habitIds = getAllHabitIds()
        return habitIds.compactMap { getHabitData(for: $0) }
    }

    // MARK: - Pending Widget Toggles

    func appendPendingToggle(habitId: UUID, dayKey: Int, completed: Bool) {
        var queue = loadPendingToggles()
        queue.append(PendingHabitToggle(habitId: habitId, dayKey: dayKey, completed: completed, timestamp: Date()))
        savePendingToggles(queue)
    }

    /// Returns all queued toggles and clears the queue.
    func drainPendingToggles() -> [PendingHabitToggle] {
        let queue = loadPendingToggles()
        defaults?.removeObject(forKey: Self.pendingTogglesKey)
        return queue
    }

    /// Put drained toggles back at the front of the queue (preserving any
    /// the widget appended in the meantime) so they retry on next activation.
    func requeuePendingToggles(_ toggles: [PendingHabitToggle]) {
        guard !toggles.isEmpty else { return }
        var queue = loadPendingToggles()
        queue.insert(contentsOf: toggles, at: 0)
        savePendingToggles(queue)
    }

    private func loadPendingToggles() -> [PendingHabitToggle] {
        guard let data = defaults?.data(forKey: Self.pendingTogglesKey) else { return [] }
        return (try? JSONDecoder().decode([PendingHabitToggle].self, from: data)) ?? []
    }

    private func savePendingToggles(_ queue: [PendingHabitToggle]) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        defaults?.set(data, forKey: Self.pendingTogglesKey)
    }
}

// MARK: - Habit Data Structure for Widget

struct HabitData: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let completedDates: [Date]
    let freezeUsedDates: [Date]?   // optional: older saved JSON won't have it

    init(id: UUID, name: String, createdAt: Date, completedDates: [Date], freezeUsedDates: [Date]? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.completedDates = completedDates
        self.freezeUsedDates = freezeUsedDates
    }

    #if !WIDGET_EXTENSION
    init(from habit: Habit) {
        self.id = habit.id
        self.name = habit.name
        self.createdAt = habit.createdAt
        self.completedDates = habit.completedDatesArray
        self.freezeUsedDates = habit.freezeUsedDatesArray
    }
    #endif

    // MARK: - Day-key helpers

    var completedKeys: Set<Int> {
        ContinuumDay.keys(fromStorage: completedDates)
    }

    // MARK: - Computed Properties

    var isCompletedToday: Bool {
        completedKeys.contains(ContinuumDay.todayKey())
    }

    /// Same numbers as Habit.consistency / consistencyTrend in the app.
    var consistency: ConsistencyTally {
        HabitMath.consistency(completed: completedKeys, todayKey: ContinuumDay.todayKey())
    }

    var consistencyWeekAgo: ConsistencyTally {
        HabitMath.consistencyWeekAgo(completed: completedKeys, todayKey: ContinuumDay.todayKey())
    }

    var consistencyTrend: Int? {
        HabitMath.trend(now: consistency, weekAgo: consistencyWeekAgo)
    }

    func historyCompletionFlags(daysBack: Int = 66, asOf date: Date = Date()) -> [Bool] {
        HabitMath.historyFlags(
            completed: completedKeys,
            asOfKey: ContinuumDay.key(for: date),
            daysBack: daysBack
        )
    }

    // MARK: - Widget intent support

    /// Returns a copy with today's completion toggled (canonical storage dates).
    func togglingToday() -> (data: HabitData, nowCompleted: Bool) {
        let today = ContinuumDay.todayKey()
        var keys = completedKeys
        let nowCompleted: Bool
        if keys.contains(today) {
            keys.remove(today)
            nowCompleted = false
        } else {
            keys.insert(today)
            nowCompleted = true
        }
        let dates = keys.sorted().map { ContinuumDay.storageDate(for: $0) }
        let updated = HabitData(
            id: id,
            name: name,
            createdAt: createdAt,
            completedDates: dates,
            freezeUsedDates: freezeUsedDates
        )
        return (updated, nowCompleted)
    }
}

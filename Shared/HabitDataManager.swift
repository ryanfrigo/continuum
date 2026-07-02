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

// MARK: - Streak / history math over day keys
// Shared between Habit (app) and HabitData (widget) so both always agree.
enum HabitMath {

    /// Current streak ending at `asOfKey`. Frozen days bridge AND count,
    /// so a used streak freeze actually preserves the displayed streak.
    static func currentStreak(completed: Set<Int>, frozen: Set<Int>, asOfKey: Int) -> Int {
        var count = 0
        var cursor = asOfKey
        while completed.contains(cursor) || frozen.contains(cursor) {
            count += 1
            cursor = ContinuumDay.key(byAdding: -1, to: cursor)
        }
        return count
    }

    /// Longest streak anywhere in history (frozen days bridge and count).
    static func longestStreak(completed: Set<Int>, frozen: Set<Int>) -> Int {
        let all = completed.union(frozen)
        guard !all.isEmpty else { return 0 }
        var longest = 0
        for key in all {
            // Only start counting at the beginning of a run
            if all.contains(ContinuumDay.key(byAdding: -1, to: key)) { continue }
            var length = 0
            var cursor = key
            while all.contains(cursor) {
                length += 1
                cursor = ContinuumDay.key(byAdding: 1, to: cursor)
            }
            longest = max(longest, length)
        }
        return longest
    }

    /// Fraction of the last `daysBack` days (ending at `asOfKey`) completed.
    static func health(completed: Set<Int>, asOfKey: Int, daysBack: Int = 66) -> Double {
        guard daysBack > 0 else { return 0 }
        var done = 0
        var cursor = asOfKey
        for _ in 0..<daysBack {
            if completed.contains(cursor) { done += 1 }
            cursor = ContinuumDay.key(byAdding: -1, to: cursor)
        }
        return Double(done) / Double(daysBack)
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

    var frozenKeys: Set<Int> {
        ContinuumDay.keys(fromStorage: freezeUsedDates ?? [])
    }

    // MARK: - Computed Properties

    var isCompletedToday: Bool {
        completedKeys.contains(ContinuumDay.todayKey())
    }

    var currentStreak: Int {
        currentStreak(asOf: Date())
    }

    func currentStreak(asOf date: Date = Date()) -> Int {
        HabitMath.currentStreak(
            completed: completedKeys,
            frozen: frozenKeys,
            asOfKey: ContinuumDay.key(for: date)
        )
    }

    var habitHealth: Double {
        habitHealth(asOf: Date())
    }

    func habitHealth(asOf date: Date = Date()) -> Double {
        HabitMath.health(completed: completedKeys, asOfKey: ContinuumDay.key(for: date))
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

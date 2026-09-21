//
//  continuumTests.swift
//  continuumTests
//
//  Real coverage for the logic users trust their streaks to:
//  day-key math, streaks, freezes, graduation, migration, and the
//  timezone-change scenarios that silently corrupt naive habit trackers.
//

import Testing
import Foundation
@testable import continuum

// MARK: - Helpers

private func calendar(_ tzId: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: tzId)!
    return c
}

private let utc = calendar("UTC")

/// A live Date at the given local wall-clock time in the given calendar.
private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 15, in cal: Calendar = utc) -> Date {
    var c = DateComponents()
    c.year = y; c.month = m; c.day = d; c.hour = hour
    return cal.date(from: c)!
}

// Every suite mutates the global test seam `ContinuumDay.calendar`, and
// Swift Testing runs sibling suites in parallel — so all suites are nested
// under one serialized root (`.serialized` applies recursively).
@Suite(.serialized)
struct ContinuumSerializedTests {}

// MARK: - Day key math

extension ContinuumSerializedTests {
@Suite(.serialized)
struct DayKeyTests {

    init() { ContinuumDay.calendar = utc }

    @Test func keyRoundTripsThroughStorage() {
        let key = 20260612
        let stored = ContinuumDay.storageDate(for: key)
        #expect(ContinuumDay.isCanonical(stored))
        #expect(ContinuumDay.key(forStorage: stored) == key)
    }

    @Test func keyForLiveDate() {
        #expect(ContinuumDay.key(for: date(2026, 6, 12)) == 20260612)
    }

    @Test func steppingCrossesMonthAndYearBoundaries() {
        #expect(ContinuumDay.key(byAdding: -1, to: 20260101) == 20251231)
        #expect(ContinuumDay.key(byAdding: 1, to: 20251231) == 20260101)
        #expect(ContinuumDay.key(byAdding: -1, to: 20260301) == 20260228)
        #expect(ContinuumDay.key(byAdding: -1, to: 20240301) == 20240229) // leap year
        #expect(ContinuumDay.key(byAdding: 30, to: 20260612) == 20260712)
    }

    @Test func daysBetween() {
        #expect(ContinuumDay.daysBetween(20260612, 20260613) == 1)
        #expect(ContinuumDay.daysBetween(20260613, 20260612) == -1)
        #expect(ContinuumDay.daysBetween(20251231, 20260101) == 1)
        #expect(ContinuumDay.daysBetween(20260101, 20261231) == 364)
    }

    @Test func weekdayIsTimezoneIndependent() {
        // 2026-06-12 is a Friday (weekday 6) no matter where you are
        ContinuumDay.calendar = calendar("Pacific/Honolulu")
        #expect(ContinuumDay.weekday(of: 20260612) == 6)
        ContinuumDay.calendar = calendar("Asia/Tokyo")
        #expect(ContinuumDay.weekday(of: 20260612) == 6)
        ContinuumDay.calendar = utc
    }
}
}

// MARK: - Streaks

extension ContinuumSerializedTests {
@Suite(.serialized)
struct StreakTests {

    init() { ContinuumDay.calendar = utc }

    @Test func toggleCompletionMarksAndUnmarksDay() {
        let habit = Habit(name: "Test")
        let day = date(2026, 6, 12)

        habit.toggleCompletion(for: day)
        #expect(habit.isCompleted(on: day))
        #expect(habit.completedDatesArray.count == 1)
        #expect(ContinuumDay.isCanonical(habit.completedDatesArray[0]))

        habit.toggleCompletion(for: day)
        #expect(!habit.isCompleted(on: day))
        #expect(habit.completedDatesArray.isEmpty)
    }

    @Test func consecutiveDaysFormAStreak() {
        let habit = Habit(name: "Test")
        for offset in 0..<5 {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -offset, to: 20260612))
        }
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 5)
    }

    @Test func gapBreaksStreak() {
        let habit = Habit(name: "Test")
        habit.setCompleted(true, forDayKey: 20260612)
        habit.setCompleted(true, forDayKey: 20260611)
        // gap on 06-10
        habit.setCompleted(true, forDayKey: 20260609)
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 2)
    }

    @Test func streakAsOfPastDate() {
        let habit = Habit(name: "Test")
        for key in [20260601, 20260602, 20260603] {
            habit.setCompleted(true, forDayKey: key)
        }
        #expect(habit.currentStreak(asOf: date(2026, 6, 3)) == 3)
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 0)
    }

    @Test func longestStreakFindsBestRun() {
        let habit = Habit(name: "Test")
        // Isolated run of 2
        for key in [20260101, 20260102] { habit.setCompleted(true, forDayKey: key) }
        // Isolated run of 5, crossing a month boundary (Feb 28 – Mar 4)
        for offset in 0..<5 { habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: offset, to: 20260228)) }
        #expect(habit.longestStreak() == 5)
        // Current streak is still 0 — longest is historical
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 0)
    }

    @Test func setCurrentStreakForcesExactLength() {
        let habit = Habit(name: "Test")
        // Pre-existing longer chain
        for offset in 0..<10 {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -offset, to: 20260612))
        }
        habit.setCurrentStreak(5, asOf: date(2026, 6, 12))
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 5)

        habit.setCurrentStreak(0, asOf: date(2026, 6, 12))
        #expect(!habit.isCompleted(on: date(2026, 6, 12)))
    }

    @Test func addRecentDaysDoesNotDuplicate() {
        let habit = Habit(name: "Test")
        habit.setCompleted(true, forDayKey: 20260612)
        habit.addRecentDays(3, asOf: date(2026, 6, 12))
        #expect(habit.completedDatesArray.count == 3)
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 3)
    }

    @Test func healthIsFractionOfLast66Days() {
        let habit = Habit(name: "Test")
        for offset in 0..<33 {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -offset, to: 20260612))
        }
        #expect(abs(habit.habitHealth(asOf: date(2026, 6, 12)) - 0.5) < 0.001)
    }

    @Test func historyFlagsEndWithToday() {
        let habit = Habit(name: "Test")
        habit.setCompleted(true, forDayKey: 20260612)
        let flags = habit.historyCompletionFlags(daysBack: 66, asOf: date(2026, 6, 12))
        #expect(flags.count == 66)
        #expect(flags.last == true)
        #expect(flags.dropLast().allSatisfy { $0 == false })
    }
}
}

// MARK: - Streak freezes

extension ContinuumSerializedTests {
@Suite(.serialized)
struct FreezeTests {

    init() { ContinuumDay.calendar = utc }

    @Test func grantIsCappedAtThree() {
        let habit = Habit(name: "Test")
        habit.grantStreakFreeze(count: 5)
        #expect(habit.streakFreezeCount == 3)
    }

    @Test func frozenDayPreservesAndCountsInStreak() {
        let habit = Habit(name: "Test")
        // Completed two days ago and today; frozen yesterday
        habit.setCompleted(true, forDayKey: 20260610)
        habit.setCompleted(true, forDayKey: 20260612)
        habit.freezeUsedDatesArray = [ContinuumDay.storageDate(for: 20260611)]

        // The freeze bridges the gap — streak is 3, not 1
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 3)
        #expect(habit.currentStreakWithFreezes(asOf: date(2026, 6, 12)) == 3)
    }

    @Test func cannotFreezeCompletedDay() {
        let habit = Habit(name: "Test")
        habit.grantStreakFreeze()
        // "Yesterday" relative to the real clock — complete it, then try to freeze
        let yesterdayKey = ContinuumDay.key(byAdding: -1, to: ContinuumDay.todayKey())
        habit.setCompleted(true, forDayKey: yesterdayKey)
        #expect(habit.useStreakFreeze() == false)
        #expect(habit.streakFreezeCount == 1)
    }

    @Test func useFreezeConsumesOneAndMarksYesterday() {
        let habit = Habit(name: "Test")
        habit.grantStreakFreeze()
        #expect(habit.useStreakFreeze() == true)
        #expect(habit.streakFreezeCount == 0)
        #expect(habit.isFreezeActiveToday)
        // Second use fails — none left and yesterday already frozen
        #expect(habit.useStreakFreeze() == false)
    }
}
}

// MARK: - Graduation

extension ContinuumSerializedTests {
@Suite(.serialized)
struct GraduationTests {

    init() { ContinuumDay.calendar = utc }

    @Test func graduatesAtSixtySixConsecutiveDays() {
        let habit = Habit(name: "Test")
        let todayKey = ContinuumDay.todayKey()
        for offset in 0..<66 {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -offset, to: todayKey))
        }
        #expect(habit.checkAndMarkGraduation() == true)
        #expect(habit.isGraduated)
        // Only marks once
        #expect(habit.checkAndMarkGraduation() == false)
    }

    @Test func doesNotGraduateAtSixtyFive() {
        let habit = Habit(name: "Test")
        let todayKey = ContinuumDay.todayKey()
        for offset in 0..<65 {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -offset, to: todayKey))
        }
        #expect(habit.checkAndMarkGraduation() == false)
        #expect(!habit.isGraduated)
    }
}
}

// MARK: - Timezone safety (the bugs this rewrite exists to prevent)

extension ContinuumSerializedTests {
@Suite(.serialized)
struct TimezoneTests {

    init() { ContinuumDay.calendar = utc }

    @Test func completedDaysSurviveTimezoneChange() {
        // Complete a habit while "in" Tokyo
        ContinuumDay.calendar = calendar("Asia/Tokyo")
        let habit = Habit(name: "Test")
        let tokyoEvening = date(2026, 6, 12, hour: 21, in: calendar("Asia/Tokyo"))
        habit.toggleCompletion(for: tokyoEvening)
        #expect(habit.completedDayKeys == [20260612])

        // Fly to Honolulu (21 hours behind Tokyo)
        ContinuumDay.calendar = calendar("Pacific/Honolulu")

        // The recorded day must still be June 12 — with the old midnight-local
        // storage, this exact scenario shifted history back a day.
        #expect(habit.completedDayKeys == [20260612])

        ContinuumDay.calendar = utc
    }

    @Test func streakIntactAfterWestwardTravel() {
        ContinuumDay.calendar = calendar("America/New_York")
        let habit = Habit(name: "Test")
        let ny = calendar("America/New_York")
        habit.toggleCompletion(for: date(2026, 6, 10, in: ny))
        habit.toggleCompletion(for: date(2026, 6, 11, in: ny))
        habit.toggleCompletion(for: date(2026, 6, 12, in: ny))

        ContinuumDay.calendar = calendar("Pacific/Honolulu")
        let hnl = calendar("Pacific/Honolulu")
        // Same wall-clock day in Honolulu — streak must still be 3
        #expect(habit.currentStreak(asOf: date(2026, 6, 12, in: hnl)) == 3)

        ContinuumDay.calendar = utc
    }

    @Test func legacyMidnightDatesMigrateToSameDay() {
        ContinuumDay.calendar = calendar("America/New_York")
        let ny = calendar("America/New_York")

        let habit = Habit(name: "Test")
        // Simulate v3.0 storage: midnight-local timestamps written directly
        let legacy = [
            ny.startOfDay(for: date(2026, 6, 10, in: ny)),
            ny.startOfDay(for: date(2026, 6, 11, in: ny)),
            ny.startOfDay(for: date(2026, 6, 12, in: ny)),
        ]
        habit.completedDates = legacy
        #expect(legacy.allSatisfy { !ContinuumDay.isCanonical($0) })

        // Migration (runs on launch, same timezone as the data was written in)
        let changed = habit.migrateToCanonicalStorage()
        #expect(changed)
        #expect(habit.completedDatesArray.allSatisfy { ContinuumDay.isCanonical($0) })
        #expect(habit.completedDayKeys == [20260610, 20260611, 20260612])

        // Second run is a no-op
        #expect(habit.migrateToCanonicalStorage() == false)

        ContinuumDay.calendar = utc
    }

    @Test func legacyAucklandMidnightsDoNotShiftBackADay() {
        // NZST is UTC+12: local midnight IS 12:00:00 UTC of the previous day,
        // so legacy dates from these zones collide with a naive noon-UTC
        // canonical marker. Migration must not shift this user's history.
        ContinuumDay.calendar = calendar("Pacific/Auckland")
        let akl = calendar("Pacific/Auckland")

        let habit = Habit(name: "Test")
        habit.completedDates = [
            akl.startOfDay(for: date(2026, 6, 10, in: akl)),
            akl.startOfDay(for: date(2026, 6, 11, in: akl)),
            akl.startOfDay(for: date(2026, 6, 12, in: akl)),
        ]

        // Read path must be right even before migration runs
        #expect(habit.completedDayKeys == [20260610, 20260611, 20260612])

        #expect(habit.migrateToCanonicalStorage())
        #expect(habit.completedDayKeys == [20260610, 20260611, 20260612])
        #expect(habit.completedDatesArray.allSatisfy { ContinuumDay.isCanonical($0) })
        #expect(habit.currentStreak(asOf: date(2026, 6, 12, in: akl)) == 3)

        ContinuumDay.calendar = utc
    }

    @Test func dstTransitionDoesNotBreakStreak() {
        // US DST spring-forward: March 8, 2026 (2am -> 3am, a 23-hour day)
        ContinuumDay.calendar = calendar("America/New_York")
        let ny = calendar("America/New_York")
        let habit = Habit(name: "Test")
        habit.toggleCompletion(for: date(2026, 3, 7, in: ny))
        habit.toggleCompletion(for: date(2026, 3, 8, in: ny))
        habit.toggleCompletion(for: date(2026, 3, 9, in: ny))
        #expect(habit.currentStreak(asOf: date(2026, 3, 9, in: ny)) == 3)

        ContinuumDay.calendar = utc
    }
}
}

// MARK: - Widget data parity

extension ContinuumSerializedTests {
@Suite(.serialized)
struct WidgetParityTests {

    init() { ContinuumDay.calendar = utc }

    @Test func widgetSnapshotAgreesWithApp() {
        let habit = Habit(name: "Test")
        habit.setCompleted(true, forDayKey: 20260610)
        habit.setCompleted(true, forDayKey: 20260612)
        habit.freezeUsedDatesArray = [ContinuumDay.storageDate(for: 20260611)]

        let data = HabitData(from: habit)
        let asOf = date(2026, 6, 12)
        // Freeze bridging must match between app and widget
        #expect(data.currentStreak(asOf: asOf) == habit.currentStreak(asOf: asOf))
        #expect(data.currentStreak(asOf: asOf) == 3)
        #expect(abs(data.habitHealth(asOf: asOf) - habit.habitHealth(asOf: asOf)) < 0.0001)
    }

    @Test func togglingTodayProducesCanonicalDatesAndQueueState() {
        let habit = Habit(name: "Test")
        let data = HabitData(from: habit)

        let (toggled, nowCompleted) = data.togglingToday()
        #expect(nowCompleted == true)
        #expect(toggled.isCompletedToday)
        #expect(toggled.completedDates.allSatisfy { ContinuumDay.isCanonical($0) })

        let (untoggled, nowCompleted2) = toggled.togglingToday()
        #expect(nowCompleted2 == false)
        #expect(!untoggled.isCompletedToday)
        #expect(untoggled.completedDates.isEmpty)
    }
}
}

// MARK: - Perfect weeks

extension ContinuumSerializedTests {
@Suite(.serialized)
struct PerfectWeekTests {

    init() { ContinuumDay.calendar = utc }

    @Test func countsTrailingPerfectDays() {
        let a: (Set<Int>, Int) = (Set((8...12).map { 20260600 + $0 }), 20260601)
        let b: (Set<Int>, Int) = ([20260611, 20260612], 20260611)

        // Days 11–12: both active and complete. Days 8–10: only `a` existed
        // and completed. Day 7: `a` active but not complete → run ends.
        let run = HabitMath.consecutivePerfectDays(habits: [a, b], asOfKey: 20260612)
        #expect(run == 5)
    }

    @Test func missedTodayMeansZero() {
        let a: (Set<Int>, Int) = ([20260611], 20260601)
        #expect(HabitMath.consecutivePerfectDays(habits: [a], asOfKey: 20260612) == 0)
    }

    @Test func noHabitsMeansZero() {
        #expect(HabitMath.consecutivePerfectDays(habits: [], asOfKey: 20260612) == 0)
    }

    @Test func sevenStraightPerfectDaysIsOneWeek() {
        let keys = Set((0..<7).map { ContinuumDay.key(byAdding: -$0, to: 20260612) })
        let a: (Set<Int>, Int) = (keys, 20260101)
        let b: (Set<Int>, Int) = (keys, 20260101)
        let run = HabitMath.consecutivePerfectDays(habits: [a, b], asOfKey: 20260612)
        #expect(run == 7)
        #expect(run % 7 == 0)
    }
}
}

// MARK: - CloudKit duplicate merging

extension ContinuumSerializedTests {
@Suite(.serialized)
struct DedupeTests {

    init() { ContinuumDay.calendar = utc }

    @Test func absorbMergesHistoriesWithoutLosingDays() {
        let id = UUID()
        let a = Habit(id: id, name: "Run")
        a.setCompleted(true, forDayKey: 20260610)
        a.setCompleted(true, forDayKey: 20260611)
        a.streakFreezeCount = 1

        let b = Habit(id: id, name: "Run")
        b.setCompleted(true, forDayKey: 20260611)
        b.setCompleted(true, forDayKey: 20260612)
        b.streakFreezeCount = 2
        b.graduatedAt = Date()

        a.absorb(b)
        #expect(a.completedDayKeys == [20260610, 20260611, 20260612])
        #expect(a.streakFreezeCount == 2)
        #expect(a.isGraduated)
        #expect(a.currentStreak(asOf: date(2026, 6, 12)) == 3)
    }
}
}

// MARK: - Notification planning

extension ContinuumSerializedTests {
@Suite(.serialized)
struct NotificationPlannerTests {

    init() { ContinuumDay.calendar = utc }

    private let today = 20260914

    /// A habit with a reminder at `hour`:00 and a run of `streak` days ending yesterday.
    private func habit(streak: Int, reminderHour: Int = 9, doneToday: Bool = false) -> Habit {
        let h = Habit(name: "Read", reminderEnabled: true, reminderHour: reminderHour)
        for back in 1...max(streak, 1) where streak > 0 {
            h.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -back, to: today))
        }
        if doneToday { h.setCompleted(true, forDayKey: today) }
        return h
    }

    private func plan(_ h: Habit, hour: Int = 7, minute: Int = 0) -> [PlannedNotification] {
        NotificationPlanner.plan(for: h, todayKey: today, hour: hour, minute: minute)
    }

    @Test func disabledReminderSchedulesNothingIncludingStreakAlerts() {
        let h = habit(streak: 30)
        h.reminderEnabled = false
        #expect(plan(h).isEmpty)
    }

    @Test func morningReminderUsesTheStreakAtStakeNotZero() {
        let h = habit(streak: 40)
        let reminder = plan(h).first { $0.identifier == NotificationID.reminder(habitId: h.id, dayKey: today) }
        #expect(reminder != nil)
        #expect(reminder!.body.contains("40"))
        #expect(!reminder!.body.contains("Day one"))
    }

    @Test func completedTodaySilencesTodayAndArmsTomorrow() {
        let h = habit(streak: 5, doneToday: true)
        let items = plan(h)
        #expect(!items.contains { $0.dayKey == today })

        let tomorrow = ContinuumDay.key(byAdding: 1, to: today)
        let alert = items.first { $0.identifier == NotificationID.streakAlert(habitId: h.id, dayKey: tomorrow) }
        #expect(alert?.title == "6-day Read streak ends at midnight")
        #expect(alert?.hour == 20)
    }

    @Test func daysWhoseStreakIsUnknownGetNeutralText() {
        let h = habit(streak: 12)   // today not done: tomorrow's streak depends on today
        let later = plan(h).filter { $0.dayKey != today }
        #expect(!later.isEmpty)
        #expect(later.allSatisfy { !$0.body.contains("12") && !$0.body.contains("13") })
        #expect(!later.contains { $0.identifier.hasPrefix(NotificationID.streakAlertPrefix) })
    }

    @Test func availableFreezeSuppressesStreakAlert() {
        let h = habit(streak: 10)
        h.streakFreezeCount = 1
        #expect(!plan(h).contains { $0.identifier.hasPrefix(NotificationID.streakAlertPrefix) })
    }

    @Test func shortStreaksGetNoAlert() {
        #expect(!plan(habit(streak: 2)).contains { $0.identifier.hasPrefix(NotificationID.streakAlertPrefix) })
        #expect(plan(habit(streak: 3)).contains { $0.identifier.hasPrefix(NotificationID.streakAlertPrefix) })
    }

    @Test func pastTimesTodayAreSkipped() {
        let h = habit(streak: 10)
        let items = plan(h, hour: 20, minute: 30)
        #expect(!items.contains { $0.dayKey == today })
    }

    @Test func reminderAtTheExactCurrentMinuteIsSkipped() {
        let h = habit(streak: 0)
        #expect(!plan(h, hour: 9, minute: 0).contains { $0.dayKey == today })
        #expect(plan(h, hour: 8, minute: 59).contains { $0.dayKey == today })
    }

    @Test func eveningReminderReplacesTheStreakAlert() {
        let h = habit(streak: 10, reminderHour: 21)
        let items = plan(h)
        #expect(!items.contains { $0.identifier.hasPrefix(NotificationID.streakAlertPrefix) })
        #expect(items.contains { $0.dayKey == today && $0.hour == 21 })
    }

    @Test func horizonCrossesMonthBoundaryWithDateKeyedIds() {
        let h = Habit(name: "Read", reminderEnabled: true)
        let keys = NotificationPlanner.plan(for: h, todayKey: 20260930, hour: 7, minute: 0).map(\.dayKey)
        #expect(keys == [20260930, 20261001, 20261002])
    }

    @Test func manyHabitsCapAtSystemLimitKeepingSoonest() {
        let habits = (0..<20).map { _ in habit(streak: 5) }
        let items = NotificationPlanner.plan(for: habits, todayKey: today, hour: 7, minute: 0)
        #expect(items.count == NotificationPlanner.systemPendingLimit)
        #expect(items.map(\.fireOrder) == items.map(\.fireOrder).sorted())
        // Every habit keeps today's reminder and today's streak alert
        #expect(items.filter { $0.dayKey == today }.count == 40)
    }

    @Test func legacyAndCurrentIdsAreOwned() {
        let id = UUID()
        #expect(NotificationID.isOwned("habit-reminder-\(id.uuidString)-day3"))
        #expect(NotificationID.isOwned("streak-risk-\(id.uuidString)-next"))
        #expect(NotificationID.isOwned(NotificationID.reminder(habitId: id, dayKey: today)))
        #expect(!NotificationID.isOwned("something-else"))
    }
}
}

// MARK: - Per-day completion ledger (cross-device merge)

import SwiftData

extension ContinuumSerializedTests {
@Suite(.serialized)
struct CompletionLedgerTests {

    init() { ContinuumDay.calendar = utc }

    private func mark(_ day: Int, _ done: Bool, at seconds: TimeInterval, id: UUID = UUID()) -> MarkSnapshot {
        MarkSnapshot(markId: id, dayKey: day, isCompleted: done, modifiedAt: Date(timeIntervalSince1970: seconds))
    }

    @Test func editsToDifferentDaysOnTwoDevicesBothSurvive() {
        // Phone marked Monday, iPad marked Tuesday; the iPad's array won the
        // last-writer-wins race and only has Tuesday.
        let result = CompletionLedger.merge(
            arrayKeys: [20260915],
            marks: [mark(20260914, true, at: 100), mark(20260915, true, at: 200)]
        )
        #expect(result.completed == [20260914, 20260915])
    }

    @Test func unCompletionBeatsStaleArrayCopy() {
        let result = CompletionLedger.merge(
            arrayKeys: [20260914],
            marks: [mark(20260914, true, at: 100), mark(20260914, false, at: 200)]
        )
        #expect(result.completed.isEmpty)
        #expect(result.duplicateMarkIds.count == 1)
    }

    @Test func unmarkedDaysFollowTheArraySoA33DeviceCanStillUncomplete() {
        // Old history lives only in the array; a 3.3 device then un-completes 09-02
        let before = CompletionLedger.merge(arrayKeys: [20260901, 20260902], marks: [])
        #expect(before.completed == [20260901, 20260902])
        let after = CompletionLedger.merge(arrayKeys: [20260901], marks: [])
        #expect(after.completed == [20260901])
    }

    @Test func tiesKeepCompletionAndPickSameSurvivorOnEveryDevice() {
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let forward = CompletionLedger.merge(arrayKeys: [], marks: [mark(20260914, true, at: 5, id: b), mark(20260914, true, at: 5, id: a)])
        let reverse = CompletionLedger.merge(arrayKeys: [], marks: [mark(20260914, true, at: 5, id: a), mark(20260914, true, at: 5, id: b)])
        #expect(forward.duplicateMarkIds == [b])
        #expect(reverse.duplicateMarkIds == [b])

        let conflict = CompletionLedger.merge(arrayKeys: [], marks: [mark(20260914, false, at: 5), mark(20260914, true, at: 5)])
        #expect(conflict.completed == [20260914])
    }

    @MainActor
    @Test func twoDevicesConvergeThroughTheLedger() throws {
        let container = try ModelContainer(
            for: Habit.self, CompletionMark.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let habit = Habit(name: "Run")
        context.insert(habit)

        // Pre-3.4 history lives in the array; reconcile leaves it alone
        habit.completedDatesArray = [ContinuumDay.storageDate(for: 20260910)]
        #expect(!CompletionLedger.reconcile(habits: [habit], in: context))

        // Local edits record marks; toggling twice updates one mark in place
        habit.setCompleted(true, forDayKey: 20260914)
        habit.setCompleted(false, forDayKey: 20260914)
        habit.setCompleted(true, forDayKey: 20260914)
        let marks = try context.fetch(FetchDescriptor<CompletionMark>())
        #expect(marks.filter { $0.dayKey == 20260914 }.count == 1)

        // Another device's Tuesday mark arrives, then its array (which has the
        // old history and Tuesday, but not our Monday) wins last-writer-wins
        context.insert(CompletionMark(habitId: habit.id, dayKey: 20260915, isCompleted: true))
        habit.completedDatesArray = [20260910, 20260915].map { ContinuumDay.storageDate(for: $0) }

        #expect(CompletionLedger.reconcile(habits: [habit], in: context))
        #expect(habit.completedDayKeys == [20260910, 20260914, 20260915])
        #expect(!CompletionLedger.reconcile(habits: [habit], in: context))  // idempotent

        // Un-completing on this device beats a stale array that still has the day
        habit.setCompleted(false, forDayKey: 20260915)
        habit.completedDatesArray = [20260910, 20260914, 20260915].map { ContinuumDay.storageDate(for: $0) }
        CompletionLedger.reconcile(habits: [habit], in: context)
        #expect(habit.completedDayKeys == [20260910, 20260914])
    }
}
}

// MARK: - Milestone detection

extension ContinuumSerializedTests {
@Suite(.serialized)
struct MilestoneDetectorTests {

    private func events(
        previous: Int, new: Int, graduated: Bool = false, best: Int = 0,
        previousHealth: Int = 100, newHealth: Int = 100, minorShown: Bool = false
    ) -> [CelebrationEvent] {
        MilestoneDetector.events(
            previousStreak: previous, newStreak: new, isAlreadyGraduated: graduated,
            allTimeBest: best, previousHealth: previousHealth, newHealth: newHealth,
            minorAlreadyShownToday: minorShown
        )
    }

    @Test func graduationFiresOnceAndNeverAgain() {
        #expect(events(previous: 65, new: 66, best: 65) == [.graduation])
        // The bug: a stale previousStreak of 0 on a formed habit re-fired this daily
        #expect(!events(previous: 0, new: 120, graduated: true, best: 200).contains(.graduation))
        #expect(events(previous: 0, new: 66, graduated: true, best: 200).isEmpty)
    }

    @Test func streakMilestonesFireOnTheirExactDay() {
        #expect(events(previous: 6, new: 7, best: 6) == [.milestone(.week)])
        #expect(events(previous: 7, new: 8, best: 8) == [])
    }

    @Test func minorMilestonesFireOncePerDayAcrossHabits() {
        #expect(events(previous: 0, new: 3, best: 0) == [.milestone(.dayThree)])
        #expect(events(previous: 0, new: 3, best: 0, minorShown: true).isEmpty)
        // A major one still fires even if a minor already showed today
        #expect(events(previous: 6, new: 7, best: 6, minorShown: true) == [.milestone(.week)])
    }

    @Test func personalRecordNeedsAnEstablishedBestAndNoMilestone() {
        #expect(events(previous: 9, new: 10, best: 9) == [.personalRecord(10)])
        #expect(events(previous: 3, new: 4, best: 3).isEmpty)          // best below the floor
        #expect(events(previous: 20, new: 21, best: 20) == [.milestone(.threeWeeks)])  // not also a record
    }

    @Test func healthMilestoneCrossingIsReportedOnce() {
        // A plain day (no milestone, no new best) that crosses 75% health
        #expect(events(previous: 9, new: 10, best: 10, previousHealth: 74, newHealth: 76) == [.health(75)])
        #expect(events(previous: 9, new: 10, best: 10, previousHealth: 76, newHealth: 78).isEmpty)
    }

    @Test func graduationHasNoTileCardButOthersDo() {
        #expect(TileCelebration(.graduation) == nil)
        let week = TileCelebration(.milestone(.week))
        #expect(week?.value == "7")
        #expect(week?.isShareable == true)
        #expect(TileCelebration(.milestone(.dayOne))?.isShareable == false)
        #expect(TileCelebration(.health(50))?.unit == "%")
    }
}
}

// MARK: - Displayed streak (the "reads 0 until today is marked" trap)

extension ContinuumSerializedTests {
@Suite(.serialized)
struct DisplayStreakTests {

    init() { ContinuumDay.calendar = utc }

    @Test func liveStreakStaysVisibleBeforeTodayIsMarked() {
        let habit = Habit(name: "Run")
        let today = ContinuumDay.todayKey()
        for back in 1...9 {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -back, to: today))
        }
        #expect(habit.currentStreak() == 0)     // counts back from today
        #expect(habit.displayStreak == 9)       // what every screen should show

        habit.setCompleted(true, forDayKey: today)
        #expect(habit.displayStreak == 10)
    }

    @Test func brokenStreakStillReadsZero() {
        let habit = Habit(name: "Run")
        let today = ContinuumDay.todayKey()
        // Last completed three days ago: the chain is genuinely gone
        habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -3, to: today))
        #expect(habit.displayStreak == 0)
    }

    @Test func appAndWidgetAgree() {
        let habit = Habit(name: "Run")
        let today = ContinuumDay.todayKey()
        for back in 1...4 {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -back, to: today))
        }
        #expect(HabitData(from: habit).displayStreak == habit.displayStreak)
    }
}
}

// MARK: - Reminder opt-in prompt

extension ContinuumSerializedTests {
@Suite(.serialized)
struct ReminderPromptTests {

    @Test func asksOnceAfterTheFirstCompletion() {
        #expect(ReminderPrompt.shouldAsk(alreadyAsked: false, permission: .notDetermined,
                                         anyReminderEnabled: false, totalCompletions: 1))
        // Not before anything has been completed, not on later completions
        #expect(!ReminderPrompt.shouldAsk(alreadyAsked: false, permission: .notDetermined,
                                          anyReminderEnabled: false, totalCompletions: 0))
        #expect(!ReminderPrompt.shouldAsk(alreadyAsked: false, permission: .notDetermined,
                                          anyReminderEnabled: false, totalCompletions: 2))
    }

    @Test func neverAsksTwiceOrAfterIosHasDecided() {
        #expect(!ReminderPrompt.shouldAsk(alreadyAsked: true, permission: .notDetermined,
                                          anyReminderEnabled: false, totalCompletions: 1))
        #expect(!ReminderPrompt.shouldAsk(alreadyAsked: false, permission: .denied,
                                          anyReminderEnabled: false, totalCompletions: 1))
        #expect(!ReminderPrompt.shouldAsk(alreadyAsked: false, permission: .authorized,
                                          anyReminderEnabled: false, totalCompletions: 1))
    }

    @Test func staysQuietIfRemindersAreAlreadySetUp() {
        #expect(!ReminderPrompt.shouldAsk(alreadyAsked: false, permission: .notDetermined,
                                          anyReminderEnabled: true, totalCompletions: 1))
    }

    @Test func defaultTimeAvoidsTheEveningStreakAlert() {
        #expect(ReminderPrompt.defaultHour < NotificationPlanner.streakAlertHour)
    }
}
}

// MARK: - Reminder copy vs. an empty grid

extension ContinuumSerializedTests {
@Suite(.serialized)
struct ReminderCopyTests {

    init() { ContinuumDay.calendar = utc }

    private let today = 20260921

    private func body(_ habit: Habit) -> String {
        NotificationPlanner.plan(for: habit, todayKey: today, hour: 7, minute: 0)
            .first { $0.identifier.hasPrefix(NotificationID.reminderPrefix) }?.body ?? ""
    }

    private func habit(completing offsets: [Int]) -> Habit {
        let h = Habit(name: "Read", reminderEnabled: true)
        for back in offsets {
            h.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -back, to: today))
        }
        return h
    }

    @Test func emptyGridGetsDayOneCopy() {
        let text = body(habit(completing: []))
        #expect(["Day one is waiting.", "The grid wants its first mark.",
                 "Every streak starts with a single dot."].contains(text))
    }

    @Test func brokenStreakIsNotToldItNeverStarted() {
        // 40 days on the grid, missed yesterday: streak is 0 but the grid is full
        let text = body(habit(completing: Array(2...41)))
        #expect(!text.contains("Day one"))
        #expect(!text.contains("first mark"))
        #expect(!text.contains("single dot"))
    }

    @Test func historyOlderThanTheGridCountsAsEmpty() {
        // The card shows 66 days; anything older isn't on it
        let text = body(habit(completing: [80, 81, 82]))
        #expect(["Day one is waiting.", "The grid wants its first mark.",
                 "Every streak starts with a single dot."].contains(text))
    }

    @Test func aSingleDotOnTheGridIsStillHistory() {
        let text = body(habit(completing: [30]))
        #expect(!text.contains("first mark"))
    }
}
}

// MARK: - Two simulated devices sharing one ledger
//
// Stands in for the on-device test nobody wants to run: two stores, records
// shuttled between them by hand, including out-of-order delivery. It cannot
// catch CloudKit-specific failures (a wrong field type in the production
// schema, entitlements, push) — only the merge logic.

extension ContinuumSerializedTests {
@Suite(.serialized)
struct TwoDeviceSyncTests {

    init() { ContinuumDay.calendar = utc }

    private func store() throws -> ModelContext {
        ModelContext(try ModelContainer(
            for: Habit.self, CompletionMark.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ))
    }

    /// Copy habits and marks from one store to another, the way CloudKit would:
    /// the habit's completedDates is a whole-array attribute (last writer wins),
    /// marks are independent records.
    private func deliver(from a: ModelContext, to b: ModelContext, arrayOnly: Bool = false) throws {
        let habits = try a.fetch(FetchDescriptor<Habit>())
        let existing = try b.fetch(FetchDescriptor<Habit>())
        for h in habits {
            if let there = existing.first(where: { $0.id == h.id }) {
                there.completedDatesArray = h.completedDatesArray
            } else {
                let copy = Habit(id: h.id, name: h.name)
                copy.completedDatesArray = h.completedDatesArray
                b.insert(copy)
            }
        }
        if !arrayOnly {
            let marks = try a.fetch(FetchDescriptor<CompletionMark>())
            let here = try b.fetch(FetchDescriptor<CompletionMark>())
            for m in marks where !here.contains(where: { $0.markId == m.markId }) {
                let copy = CompletionMark(habitId: m.habitId, dayKey: m.dayKey,
                                          isCompleted: m.isCompleted, modifiedAt: m.modifiedAt)
                copy.markId = m.markId
                b.insert(copy)
            }
        }
        try b.save()
    }

    private func keys(_ ctx: ModelContext) throws -> Set<Int> {
        try ctx.fetch(FetchDescriptor<Habit>()).first?.completedDayKeys ?? []
    }

    private func settle(_ ctx: ModelContext) throws {
        CompletionLedger.reconcile(habits: try ctx.fetch(FetchDescriptor<Habit>()), in: ctx)
    }

    @MainActor
    @Test func mondayOnOneDeviceAndTuesdayOnTheOtherBothSurvive() throws {
        let phone = try store(), pad = try store()
        let id = UUID()
        for ctx in [phone, pad] {
            let h = Habit(id: id, name: "Run")
            ctx.insert(h)
            h.setCompleted(true, forDayKey: 20260901)
            try ctx.save()
        }
        // Offline edits to different days — the case last-writer-wins used to lose
        try phone.fetch(FetchDescriptor<Habit>()).first!.setCompleted(true, forDayKey: 20260914)
        try pad.fetch(FetchDescriptor<Habit>()).first!.setCompleted(true, forDayKey: 20260915)
        try phone.save(); try pad.save()

        try deliver(from: phone, to: pad)
        try deliver(from: pad, to: phone)
        try settle(phone); try settle(pad)
        #expect(try keys(phone) == [20260901, 20260914, 20260915])
        #expect(try keys(pad) == [20260901, 20260914, 20260915])
    }

    @MainActor
    @Test func anArrayArrivingBeforeItsMarksStillConverges() throws {
        let phone = try store(), pad = try store()
        let id = UUID()
        for ctx in [phone, pad] {
            let h = Habit(id: id, name: "Run"); ctx.insert(h)
            h.setCompleted(true, forDayKey: 20260910); try ctx.save()
        }
        try phone.fetch(FetchDescriptor<Habit>()).first!.setCompleted(true, forDayKey: 20260914)
        try phone.save()
        try deliver(from: phone, to: pad, arrayOnly: true)   // record first, marks later
        try settle(pad)
        try deliver(from: phone, to: pad)
        try settle(pad)
        #expect(try keys(pad) == [20260910, 20260914])
    }

    @MainActor
    @Test func anUncompletionPropagatesInsteadOfComingBack() throws {
        let phone = try store(), pad = try store()
        let id = UUID()
        for ctx in [phone, pad] {
            let h = Habit(id: id, name: "Run"); ctx.insert(h)
            h.setCompleted(true, forDayKey: 20260914); try ctx.save()
        }
        try phone.fetch(FetchDescriptor<Habit>()).first!.setCompleted(false, forDayKey: 20260914)
        try phone.save()
        try deliver(from: phone, to: pad)
        try settle(pad)
        #expect(try keys(pad).isEmpty)

        try deliver(from: pad, to: phone)   // and it must not come back
        try settle(phone)
        #expect(try keys(phone).isEmpty)
    }
}
}

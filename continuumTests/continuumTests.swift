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

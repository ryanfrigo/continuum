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

    @Test func singleMissIsBridgedButNotCounted() {
        let habit = Habit(name: "Test")
        habit.setCompleted(true, forDayKey: 20260612)
        habit.setCompleted(true, forDayKey: 20260611)
        // grace day on 06-10
        habit.setCompleted(true, forDayKey: 20260609)
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 3)
    }

    @Test func twoMissesInARowBreakStreak() {
        let habit = Habit(name: "Test")
        for key in [20260612, 20260611, 20260608] { habit.setCompleted(true, forDayKey: key) }
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 2)
    }

    @Test func secondMissWithinAWeekCutsAtTheOlderGap() {
        let habit = Habit(name: "Test")
        // 06-01...06-12 done except 06-05 and 06-09 (four days apart)
        for day in 1...12 where day != 5 && day != 9 {
            habit.setCompleted(true, forDayKey: 20260600 + day)
        }
        // 06-09 takes the grace; 06-05 can't, so the run starts 06-06
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 6)
    }

    @Test func graceDaysAWeekApartBothBridge() {
        let habit = Habit(name: "Test")
        // 05-30...06-12 done except 06-02 and 06-09 (exactly 7 days apart)
        for offset in 0..<14 {
            let key = ContinuumDay.key(byAdding: -offset, to: 20260612)
            if key != 20260609 && key != 20260602 { habit.setCompleted(true, forDayKey: key) }
        }
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 12)
        #expect(habit.longestStreak() == 12)
    }

    @Test func unmarkedDayIsPendingGrace() {
        let habit = Habit(name: "Test")
        habit.setCompleted(true, forDayKey: 20260610)
        habit.setCompleted(true, forDayKey: 20260611)
        // 06-12 not marked yet: the streak survives if it gets done
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

// MARK: - Consistency (the number every screen shows)

extension ContinuumSerializedTests {
@Suite(.serialized)
struct ConsistencyTests {

    init() { ContinuumDay.calendar = utc }

    private let today = 20260929

    private func keys(_ backs: [Int]) -> Set<Int> {
        Set(backs.map { ContinuumDay.key(byAdding: -$0, to: today) })
    }

    @Test func nothingDoneMeansNoNumber() {
        let t = HabitMath.consistency(completed: [], todayKey: today)
        #expect(t.percent == nil)
        #expect(t.fraction == 0)
    }

    @Test func firstDayDoneIsAHundred() {
        #expect(HabitMath.consistency(completed: keys([0]), todayKey: today).percent == 100)
    }

    @Test func countsFromTheFirstDoneDayNotFromDayOneOfTheWindow() {
        // 20 of the last 20 days: the old health maths read 30%
        let t = HabitMath.consistency(completed: keys(Array(0..<20)), todayKey: today)
        #expect(t == ConsistencyTally(done: 20, counted: 20))
    }

    @Test func todayCountsOnlyOnceDone() {
        // Started 3 days ago, done 2 of them, today still open
        let t = HabitMath.consistency(completed: keys([3, 1]), todayKey: today)
        #expect(t == ConsistencyTally(done: 2, counted: 3))
        #expect(t.percent == 66)
    }

    @Test func windowIsTheSixtySixDayGrid() {
        // Done every day for 100 days: only the grid's 66 count
        let t = HabitMath.consistency(completed: keys(Array(0..<100)), todayKey: today)
        #expect(t == ConsistencyTally(done: 66, counted: 66))
        // Same, today open: 65 counted
        let open = HabitMath.consistency(completed: keys(Array(1..<100)), todayKey: today)
        #expect(open == ConsistencyTally(done: 65, counted: 65))
    }

    @Test func percentRoundsDownSoNothingImperfectReadsAHundred() {
        #expect(ConsistencyTally(done: 395, counted: 396).percent == 99)
        #expect(ConsistencyTally(done: 2, counted: 3).percent == 66)
    }

    @Test func tallyAddsForPooling() {
        let sum = ConsistencyTally(done: 1, counted: 2) + ConsistencyTally(done: 3, counted: 4)
        #expect(sum == ConsistencyTally(done: 4, counted: 6))
    }

    @Test func trendIsTheChangeInTheShownNumberOverAWeek() {
        // 20 days in: missed 4 of the first 13, then perfect for 7
        let done = keys(Array(0..<20)).subtracting(keys([17, 15, 13, 11]))
        let now = HabitMath.consistency(completed: done, todayKey: today)          // 16/20 = 80
        let then = HabitMath.consistencyWeekAgo(completed: done, todayKey: today)  // 9/13 = 69
        #expect(now.percent == 80)
        #expect(then.percent == 69)
        #expect(HabitMath.trend(now: now, weekAgo: then) == 11)
    }

    @Test func trendWaitsForSevenCountedDaysAWeekAgo() {
        let young = keys(Array(0..<13))   // a week ago it had 6 counted days
        #expect(HabitMath.trend(
            now: HabitMath.consistency(completed: young, todayKey: today),
            weekAgo: HabitMath.consistencyWeekAgo(completed: young, todayKey: today)) == nil)
        let older = keys(Array(0..<14))
        #expect(HabitMath.trend(
            now: HabitMath.consistency(completed: older, todayKey: today),
            weekAgo: HabitMath.consistencyWeekAgo(completed: older, todayKey: today)) == 0)
    }

    @Test func allTimeCountsEveryDaySinceTheFirst() {
        let t = HabitMath.allTime(completed: keys([199, 100, 0]), todayKey: today)
        #expect(t == ConsistencyTally(done: 3, counted: 200))
    }

    @Test func weeklyBlocksAreOldestFirstAndEmptyBeforeTheStart() {
        let blocks = HabitMath.weeklyBlocks(completed: keys(Array(1..<10)), todayKey: today, weeks: 3)
        #expect(blocks.count == 3)
        #expect(blocks[0] == ConsistencyTally())                        // 14–20 days back: not started
        #expect(blocks[1] == ConsistencyTally(done: 3, counted: 3))    // 7–13 back: started 9 back
        #expect(blocks[2] == ConsistencyTally(done: 6, counted: 6))    // 0–6 back, today open
    }

    @Test func comebackIsADayDoneAfterAMissOnAHabitWithARhythm() {
        // done 4, 3, 2 back · missed yesterday · done today
        #expect(HabitMath.comebackGap(completed: keys([4, 3, 2, 0]), dayKey: today) == 1)
        // three missed days
        #expect(HabitMath.comebackGap(completed: keys([6, 5, 4, 0]), dayKey: today) == 3)
        // no miss
        #expect(HabitMath.comebackGap(completed: keys([3, 2, 1, 0]), dayKey: today) == nil)
        // too little history to come back to
        #expect(HabitMath.comebackGap(completed: keys([3, 2, 0]), dayKey: today) == nil)
        // today not done
        #expect(HabitMath.comebackGap(completed: keys([4, 3, 2]), dayKey: today) == nil)
    }
}
}

// MARK: - Streak freezes

extension ContinuumSerializedTests {
@Suite(.serialized)
struct FreezeTests {

    init() { ContinuumDay.calendar = utc }

    @Test func frozenDayPreservesAndCountsInStreak() {
        let habit = Habit(name: "Test")
        // Completed two days ago and today; frozen yesterday
        habit.setCompleted(true, forDayKey: 20260610)
        habit.setCompleted(true, forDayKey: 20260612)
        habit.freezeUsedDatesArray = [ContinuumDay.storageDate(for: 20260611)]

        // A freeze from before 3.8 still bridges the gap — streak is 3, not 1
        #expect(habit.currentStreak(asOf: date(2026, 6, 12)) == 3)
    }

    @Test func frozenDaysCountAsMissedForConsistency() {
        let habit = Habit(name: "Test")
        habit.setCompleted(true, forDayKey: 20260610)
        habit.setCompleted(true, forDayKey: 20260612)
        habit.freezeUsedDatesArray = [ContinuumDay.storageDate(for: 20260611)]
        #expect(HabitMath.consistency(completed: habit.completedDayKeys, todayKey: 20260612)
                == ConsistencyTally(done: 2, counted: 3))
    }
}
}

// MARK: - Graduation

extension ContinuumSerializedTests {
@Suite(.serialized)
struct GraduationTests {

    init() { ContinuumDay.calendar = utc }

    @Test func graduatesAtSixtySixDaysDoneInAnyOrder() {
        let habit = Habit(name: "Test")
        let todayKey = ContinuumDay.todayKey()
        // Every other day: 66 days done across 131, never two in a row
        for n in 0..<66 {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -2 * n, to: todayKey))
        }
        #expect(habit.daysDone == 66)
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
        let today = ContinuumDay.todayKey()
        for back in [20, 18, 15, 9, 8, 7, 3, 1] {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -back, to: today))
        }
        let data = HabitData(from: habit)
        #expect(data.consistency == habit.consistency)
        #expect(data.consistency == ConsistencyTally(done: 8, counted: 20))
        #expect(data.consistencyTrend == habit.consistencyTrend)
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

    /// A habit with a reminder at `hour`:00, done on the given days back.
    private func habit(done backs: [Int], reminderHour: Int = 9) -> Habit {
        let h = Habit(name: "Read", reminderEnabled: true, reminderHour: reminderHour)
        for back in backs {
            h.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -back, to: today))
        }
        return h
    }

    private func plan(_ h: Habit, hour: Int = 7, minute: Int = 0) -> [PlannedNotification] {
        NotificationPlanner.plan(for: h, todayKey: today, hour: hour, minute: minute)
    }

    private func alerts(_ items: [PlannedNotification]) -> [PlannedNotification] {
        items.filter { $0.identifier.hasPrefix(NotificationID.missAlertPrefix) }
    }

    @Test func disabledReminderSchedulesNothingIncludingAlerts() {
        let h = habit(done: [5, 4, 3, 2])
        h.reminderEnabled = false
        #expect(plan(h).isEmpty)
    }

    @Test func morningReminderSaysWhatTodayDoesToTheNumber() {
        // 21 of 40 days, today open: 52% now, 22 of 41 = 53 if done
        let h = habit(done: Array(stride(from: 2, through: 40, by: 2)) + [1])
        let body = plan(h).first { $0.identifier == NotificationID.reminder(habitId: h.id, dayKey: today) }?.body
        #expect(body?.contains("53") == true)
        #expect(body?.contains("Day one") == false)
    }

    @Test func completedTodaySilencesToday() {
        #expect(!plan(habit(done: [2, 1, 0])).contains { $0.dayKey == today })
    }

    @Test func dayAfterAMissGetsTheNeverMissTwiceAlert() {
        let items = alerts(plan(habit(done: [5, 4, 3, 2])))
        #expect(items.map(\.dayKey) == [today])
        #expect(items.first?.hour == 20)
        #expect(items.first?.title == "Read: never miss twice")
    }

    @Test func twoMissesInARowGetNoAlert() {
        #expect(alerts(plan(habit(done: [5, 4, 3]))).isEmpty)
    }

    @Test func openTodayArmsTomorrowsAlertAndDoneTodayDisarmsIt() {
        let tomorrow = ContinuumDay.key(byAdding: 1, to: today)
        #expect(alerts(plan(habit(done: [3, 2, 1]))).map(\.dayKey) == [tomorrow])
        #expect(alerts(plan(habit(done: [3, 2, 1, 0]))).isEmpty)
    }

    @Test func eveningReminderReplacesTheAlert() {
        let items = plan(habit(done: [5, 4, 3, 2], reminderHour: 21))
        #expect(alerts(items).isEmpty)
        #expect(items.contains { $0.dayKey == today && $0.hour == 21 })
    }

    @Test func pastEightNoAlertTonight() {
        #expect(alerts(plan(habit(done: [5, 4, 3, 2]), hour: 20, minute: 30)).isEmpty)
    }

    @Test func daysNotYetKnownGetNeutralText() {
        // Today open: tomorrow's number depends on today
        let later = plan(habit(done: [3, 2, 1])).filter {
            $0.dayKey != today && $0.identifier.hasPrefix(NotificationID.reminderPrefix)
        }
        #expect(later.count == 2)
        #expect(later.allSatisfy { !$0.body.contains("%") })
    }

    @Test func pastTimesTodayAreSkipped() {
        #expect(!plan(habit(done: [3, 2, 1]), hour: 20, minute: 30).contains { $0.dayKey == today })
    }

    @Test func reminderAtTheExactCurrentMinuteIsSkipped() {
        let h = habit(done: [])
        #expect(!plan(h, hour: 9, minute: 0).contains { $0.dayKey == today })
        #expect(plan(h, hour: 8, minute: 59).contains { $0.dayKey == today })
    }

    @Test func horizonCrossesMonthBoundaryWithDateKeyedIds() {
        let h = Habit(name: "Read", reminderEnabled: true)
        let keys = NotificationPlanner.plan(for: h, todayKey: 20260930, hour: 7, minute: 0).map(\.dayKey)
        #expect(keys == [20260930, 20261001, 20261002])
    }

    @Test func manyHabitsCapAtSystemLimitKeepingSoonest() {
        let habits = (0..<20).map { _ in habit(done: [5, 4, 3, 2]) }
        let items = NotificationPlanner.plan(for: habits, todayKey: today, hour: 7, minute: 0)
        #expect(items.count == NotificationPlanner.systemPendingLimit)
        #expect(items.map(\.fireOrder) == items.map(\.fireOrder).sorted())
        // Every habit keeps today's reminder and today's alert
        #expect(items.filter { $0.dayKey == today }.count == 40)
    }

    @Test func legacyAndCurrentIdsAreOwned() {
        let id = UUID()
        #expect(NotificationID.isOwned("habit-reminder-\(id.uuidString)-day3"))
        #expect(NotificationID.isOwned("streak-risk-\(id.uuidString)-next"))
        #expect(NotificationID.isOwned(NotificationID.reminder(habitId: id, dayKey: today)))
        #expect(NotificationID.isOwned(NotificationID.missAlert(habitId: id, dayKey: today)))
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

    init() { ContinuumDay.calendar = utc }

    private let today = 20260929

    private func keys(_ backs: [Int]) -> Set<Int> {
        Set(backs.map { ContinuumDay.key(byAdding: -$0, to: today) })
    }

    /// Events for marking `mark` days back on top of `history`.
    private func events(_ history: [Int], mark: Int = 0, graduated: Bool = false, smallShown: Bool = false) -> [CelebrationEvent] {
        let before = keys(history)
        let marked = ContinuumDay.key(byAdding: -mark, to: today)
        return MilestoneDetector.events(
            before: before, after: before.union([marked]), markedKey: marked, todayKey: today,
            isAlreadyGraduated: graduated, smallMomentShownToday: smallShown
        )
    }

    private func isMilestone(_ e: CelebrationEvent) -> Bool { if case .milestone = e { return true }; return false }
    private func isLevel(_ e: CelebrationEvent) -> Bool { if case .level = e { return true }; return false }
    private func isComeback(_ e: CelebrationEvent) -> Bool { if case .comeback = e { return true }; return false }

    @Test func daysDoneMilestonesCountAnyOrder() {
        // 6 days scattered over two weeks, the 7th today
        #expect(events([12, 10, 8, 6, 4, 2]).contains(.milestone(.seven)))
        #expect(!events([12, 10, 8, 6, 4, 2, 1]).contains(where: isMilestone))
    }

    @Test func graduationAtSixtySixDoneEvenWithoutAStreak() {
        let every2nd = (1...65).map { $0 * 2 }
        #expect(events(every2nd) == [.graduation])
        #expect(!events(every2nd, graduated: true).contains(.graduation))
    }

    @Test func alreadyPastSixtySixGraduatesOnTheNextCompletion() {
        // Never had a 66-day streak, but 80 days done: formed on the next mark
        #expect(events(Array(1...80)) == [.graduation])
    }

    @Test func minorMilestonesAndComebacksShareOneSlotADay() {
        #expect(events([2, 1]) == [.milestone(.three)])
        #expect(events([2, 1], smallShown: true).isEmpty)
        // A major one still fires after a small moment today
        #expect(events([12, 10, 8, 6, 4, 2], smallShown: true) == [.milestone(.seven)])
        #expect(!events([6, 5, 4, 3, 2], smallShown: true).contains(where: isComeback))
    }

    @Test func levelNeedsFourteenCountedDays() {
        // 11 of 15 counted (73%) → 12 of 16 (75%)
        #expect(events([15, 14, 13, 12, 11, 10, 8, 6, 4, 2, 1]) == [.level(75)])
        // 3 of 4 → 4 of 5 moves the number, but 5 days is too young to mean it
        #expect(!events([4, 3, 1]).contains(where: isLevel))
    }

    @Test func comebackAfterOneMiss() {
        #expect(events([6, 5, 4, 3, 2]) == [.comeback(gap: 1)])
    }

    @Test func comebackAtMostOnceAWeekPerHabit() {
        // Came back 3 days ago (done 7,6,5 · missed 4 · done 3), so not again today
        #expect(!events([7, 6, 5, 3, 2]).contains(where: isComeback))
    }

    @Test func backfillingYesterdayIsNotAComeback() {
        #expect(!events([5, 4, 3], mark: 1).contains(where: isComeback))
    }

    @Test func tileCopy() {
        #expect(TileCelebration(.graduation) == nil)
        #expect(TileCelebration(.milestone(.seven))?.value == "7")
        #expect(TileCelebration(.milestone(.seven))?.isShareable == true)
        #expect(TileCelebration(.milestone(.one))?.isShareable == false)
        #expect(TileCelebration(.level(90))?.value == "90%")
        #expect(TileCelebration(.comeback(gap: 1))?.caption == "didn't miss twice")
        #expect(TileCelebration(.comeback(gap: 4))?.caption == "picked it back up")
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
        #expect(habit.currentStreak() == 9)     // unmarked today is a pending grace day
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

    @Test func defaultTimeAvoidsTheEveningAlert() {
        #expect(ReminderPrompt.defaultHour < NotificationPlanner.missAlertHour)
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
                 "Every habit starts with a single dot."].contains(text))
    }

    @Test func missedYesterdayIsNotToldItNeverStarted() {
        // 40 days on the grid, missed yesterday
        let text = body(habit(completing: Array(2...41)))
        #expect(!text.contains("Day one"))
        #expect(!text.contains("first mark"))
        #expect(!text.contains("single dot"))
    }

    @Test func historyOlderThanTheGridCountsAsEmpty() {
        // The card shows 66 days; anything older isn't on it
        let text = body(habit(completing: [80, 81, 82]))
        #expect(["Day one is waiting.", "The grid wants its first mark.",
                 "Every habit starts with a single dot."].contains(text))
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

// MARK: - When the rating prompt is offered

extension ContinuumSerializedTests {
@Suite(.serialized)
struct ReviewPromptTests {

    /// Mirrors ContentView's rule so the milestone ladder is pinned by a test.
    private func asked(daysDone: Int, alreadyAskedAt: Int) -> Int? {
        for milestone in [7, 21] where daysDone >= milestone && alreadyAskedAt < milestone {
            return milestone
        }
        return nil
    }

    @Test func asksAtSevenDaysNotOnlyAtTwentyOne() {
        #expect(asked(daysDone: 7, alreadyAskedAt: 0) == 7)
        #expect(asked(daysDone: 6, alreadyAskedAt: 0) == nil)
    }

    @Test func asksAgainAtTwentyOneButNeverTwiceForTheSameMilestone() {
        #expect(asked(daysDone: 21, alreadyAskedAt: 7) == 21)
        #expect(asked(daysDone: 30, alreadyAskedAt: 21) == nil)
        #expect(asked(daysDone: 9, alreadyAskedAt: 7) == nil)
    }
}
}

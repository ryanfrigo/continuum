# Consistency First Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship 3.8 with consistency (a percentage) as the number Continuum is about, streak mechanics demoted or retired, a rebrand to "Continuum: Consistency Tracker", and a new App Store screenshot set.

**Architecture:** All maths lives in `HabitMath` (Shared/, compiled into app and widget) as pure functions over day-key sets, returning a `ConsistencyTally` (done / counted). Views read it through thin accessors on `Habit` and `HabitData`. Celebrations come from a pure `MilestoneDetector.events(before:after:…)` that diffs the completion set either side of a mark, replacing the in-memory "previous streak" dictionaries in `ContentView`.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData + CloudKit, WidgetKit + AppIntents, Swift Testing, Xcode 27 locally, Python + Pillow for screenshot captions, Node scripts for App Store Connect.

Spec: `docs/superpowers/specs/2026-09-29-consistency-first-design.md`.

Test command used throughout (simulator "iPhone 16 Pro Max"):

```bash
xcodebuild test -scheme continuum -testPlan continuum \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  -derivedDataPath /tmp/dd-continuum 2>&1 | tail -40
```

Tests must stay nested under `ContinuumSerializedTests` (they mutate the global `ContinuumDay.calendar`).

---

## File map

| File | Change |
|---|---|
| `Shared/HabitDataManager.swift` | `ConsistencyTally`; `HabitMath.tally/consistency/consistencyWeekAgo/trend/allTime/weeklyBlocks/comebackGap`; drop `health`; `NotificationID.missAlert`; `HabitData` consistency accessors, drop streak/health accessors |
| `continuum/Models/Habit.swift` | `consistency`, `consistencyTrend`, `daysDone`; graduation at 66 days done; drop `habitHealth` and freeze spend/grant API |
| `continuum/Models/MilestoneDetector.swift` | `DaysMilestone`; events `.milestone/.level/.comeback/.graduation`; new `TileCelebration` copy |
| `continuum/Views/CelebrationView.swift` | drop `StreakMilestone`, `FreezeSaveOverlay`; graduation copy |
| `continuum/Views/Components/ConsistencyViews.swift` | NEW: `TrendLabel`, `ConsistencyHeader` |
| `continuum/ContentView.swift` | header; new milestone flow; remove freezes and previous-value state |
| `continuum/Views/HabitCardView.swift` | percentage hero + trend; pre-start cells; callback passes day key |
| `continuum/Views/HabitStatsView.swift` | hero, 12-week bars, new tiles, no freeze legend |
| `continuum/Views/ShareCardView.swift` | percentage hero |
| `continuumWidget/continuumWidget.swift` | percentages; intent clears tomorrow's miss alert |
| `continuum/Services/NotificationManager.swift` | consistency copy; never-miss-twice alert |
| `continuum/Views/{Onboarding,Walkthrough,Settings}View.swift` | copy |
| `continuumTests/continuumTests.swift` | new + rewritten suites |
| `continuumTests/SeedShots.swift` | screenshot seed |
| `scripts/aso.json`, `scripts/whats-new.txt`, `docs/ASO.md`, `README.md` | rebrand |
| `AppStoreScreenshots/3.8/` + `scripts/caption-screenshots.py` | NEW screenshot set and compositor |

---

### Task 1: Consistency maths

**Files:**
- Modify: `Shared/HabitDataManager.swift` (HabitMath, after `longestStreak`)
- Test: `continuumTests/continuumTests.swift` (new `ConsistencyTests` suite)

- [ ] **Step 1: Write the failing tests**

```swift
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
        let now = HabitMath.consistency(completed: young, todayKey: today)
        let then = HabitMath.consistencyWeekAgo(completed: young, todayKey: today)
        #expect(HabitMath.trend(now: now, weekAgo: then) == nil)
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
        #expect(blocks[0] == ConsistencyTally())                        // days 14–20 back: not started
        #expect(blocks[1] == ConsistencyTally(done: 3, counted: 3))    // days 7–13: started day 9
        #expect(blocks[2] == ConsistencyTally(done: 6, counted: 6))    // days 0–6, today open
    }

    @Test func comebackIsADayDoneAfterAMissOnAHabitWithARhythm() {
        // done 4,3,2 · missed 1 · done today
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
```

- [ ] **Step 2: Run tests, verify they fail**

Run the test command. Expected: compile errors, `ConsistencyTally` and `HabitMath.consistency` not found.

- [ ] **Step 3: Implement** (in `Shared/HabitDataManager.swift`, replacing `HabitMath.health`)

```swift
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
```

and inside `enum HabitMath`:

```swift
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
```

- [ ] **Step 4: Run tests, verify `ConsistencyTests` pass.** (Other suites fail to compile until Task 2 removes `health` callers; do Tasks 1–2 before running the full suite.)
- [ ] **Step 5: Commit** — `git commit -m "Consistency maths: tally, trend, weekly blocks, comebacks"`

### Task 2: Model accessors, graduation, freezes retired

**Files:** `continuum/Models/Habit.swift`, `Shared/HabitDataManager.swift` (HabitData), tests.

- [ ] **Step 1: Tests** — replace `GraduationTests` bodies and `WidgetParityTests.widgetSnapshotAgreesWithApp`; delete the freeze spend/grant tests and `healthIsFractionOfLast66Days`:

```swift
    @Test func graduatesAtSixtySixDaysDoneInAnyOrder() {
        let habit = Habit(name: "Test")
        let todayKey = ContinuumDay.todayKey()
        // Every other day: 66 days done across 131, never two in a row
        for n in 0..<66 {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -2 * n, to: todayKey))
        }
        #expect(habit.checkAndMarkGraduation() == true)
        #expect(habit.isGraduated)
        #expect(habit.checkAndMarkGraduation() == false)   // once
    }

    @Test func doesNotGraduateAtSixtyFiveDaysDone() {
        let habit = Habit(name: "Test")
        let todayKey = ContinuumDay.todayKey()
        for offset in 0..<65 {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -offset, to: todayKey))
        }
        #expect(habit.checkAndMarkGraduation() == false)
    }
```

```swift
    @Test func widgetSnapshotAgreesWithApp() {
        let habit = Habit(name: "Test")
        let today = ContinuumDay.todayKey()
        for back in [20, 18, 15, 9, 8, 7, 3, 1] {
            habit.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -back, to: today))
        }
        let data = HabitData(from: habit)
        #expect(data.consistency == habit.consistency)
        #expect(data.consistencyTrend == habit.consistencyTrend)
    }
```

`FreezeTests.frozenDayPreservesAndCountsInStreak` stays, minus its `currentStreakWithFreezes` line.

- [ ] **Step 2: Implement** — in `Habit`:

```swift
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

    /// Mark as graduated once 66 days are done, in any order.
    func checkAndMarkGraduation() -> Bool {
        guard graduatedAt == nil, daysDone >= HabitMath.daysToForm else { return false }
        graduatedAt = Date()
        return true
    }
```

Delete `habitHealth`, `isFreezeActiveToday`, `useStreakFreeze`, `grantStreakFreeze`, `currentStreakWithFreezes`. Comment `streakFreezeCount` as retired but kept (CloudKit fields are additive-only). In `HabitData`: add `consistency` and `consistencyTrend` mirroring the above over `completedKeys`; delete `habitHealth`, `currentStreak`, `displayStreak` (the widget stops showing streaks) and `DisplayStreakTests.appAndWidgetAgree`.

- [ ] **Step 3: Run the full suite** after Tasks 3–4 compile; commit — `"Graduate at 66 days done; retire freezes"`

### Task 3: Milestones

**Files:** `continuum/Models/MilestoneDetector.swift`, `continuum/Views/CelebrationView.swift`, tests.

- [ ] **Step 1: Tests** — replace `MilestoneDetectorTests`:

```swift
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
        return MilestoneDetector.events(before: before, after: before.union([marked]), markedKey: marked,
                                        todayKey: today, isAlreadyGraduated: graduated, smallMomentShownToday: smallShown)
    }

    @Test func daysDoneMilestonesCountAnyOrder() {
        // 6 days scattered over two weeks, the 7th today
        #expect(events([12, 10, 8, 6, 4, 2]).contains(.milestone(.seven)))
        #expect(!events([12, 10, 8, 6, 4, 2, 1]).contains { if case .milestone = $0 { return true }; return false })
    }

    @Test func graduationAtSixtySixDoneEvenWithoutAStreak() {
        let every2nd = (1...65).map { $0 * 2 }
        #expect(events(every2nd) == [.graduation])
        #expect(!events(every2nd, graduated: true).contains(.graduation))
    }

    @Test func alreadyPastSixtySixGraduatesOnTheNextCompletion() {
        #expect(events(Array(1...80)) == [.graduation])
    }

    @Test func minorMilestonesAndComebacksShareOneSlotADay() {
        #expect(events([2, 1]) == [.milestone(.three)])
        #expect(events([2, 1], smallShown: true).isEmpty)
        #expect(events([12, 10, 8, 6, 4, 2], smallShown: true) == [.milestone(.seven)])
    }

    @Test func levelNeedsFourteenCountedDays() {
        // 11 of 15 counted (73%) → 12 of 16 (75%)
        let history = [15, 14, 13, 12, 11, 10, 8, 6, 4, 2, 1]
        #expect(events(history).contains(.level(75)))
        // 5 counted days: 3 of 4 → 4 of 5 is a crossing but too young to mean it
        #expect(!events([4, 3, 1]).contains { if case .level = $0 { return true }; return false })
    }

    @Test func comebackAfterOneMiss() {
        #expect(events([6, 5, 4, 3, 2]) == [.comeback(gap: 1)])
    }

    @Test func comebackAtMostOnceAWeekPerHabit() {
        // Came back 3 days ago (done 7,6,5 · missed 4 · done 3), so not again today
        #expect(!events([7, 6, 5, 3, 2]).contains(.comeback(gap: 1)))
    }

    @Test func backfillingYesterdayIsNotAComeback() {
        #expect(!events([5, 4, 3], mark: 1).contains { if case .comeback = $0 { return true }; return false })
    }

    @Test func tileCopy() {
        #expect(TileCelebration(.graduation) == nil)
        #expect(TileCelebration(.milestone(.seven))?.value == "7")
        #expect(TileCelebration(.milestone(.seven))?.isShareable == true)
        #expect(TileCelebration(.milestone(.one))?.isShareable == false)
        #expect(TileCelebration(.level(90))?.value == "90%")
        #expect(TileCelebration(.comeback(gap: 1))?.caption == "didn't miss twice")
    }
}
```

- [ ] **Step 2: Implement** — `MilestoneDetector.swift` becomes:

```swift
/// Days-done milestones: total days marked, in any order. A count that only
/// goes up can't be lost, so a bad week never takes one back.
enum DaysMilestone: Int, CaseIterable {
    // Dense early (days 1–7 decide retention), scarce later.
    case one = 1, three = 3, five = 5, seven = 7, twentyOne = 21, formed = 66, hundred = 100, year = 365

    var isMinor: Bool { rawValue <= 5 }

    /// The biggest milestone passed going from `before` to `after` days done.
    static func crossed(from before: Int, to after: Int) -> DaysMilestone? {
        allCases.last { before < $0.rawValue && $0.rawValue <= after }
    }
}

enum CelebrationEvent: Equatable {
    case graduation
    case milestone(DaysMilestone)
    case level(Int)          // consistency crossed 50, 75, 90 or 100
    case comeback(gap: Int)  // marked after missing the day before

    /// Minor milestones and comebacks share one slot a day across habits.
    var isSmallMoment: Bool {
        switch self {
        case .milestone(let m): return m.isMinor
        case .comeback: return true
        default: return false
        }
    }
}

enum MilestoneDetector {
    static let levels = [50, 75, 90, 100]
    static let levelMinimumCounted = 14

    static func events(before: Set<Int>, after: Set<Int>, markedKey: Int, todayKey: Int,
                       isAlreadyGraduated: Bool, smallMomentShownToday: Bool) -> [CelebrationEvent] {
        // Once per habit. No crossing required, so anyone already past 66 when
        // this rule arrived graduates on their next completion.
        if after.count >= HabitMath.daysToForm && !isAlreadyGraduated { return [.graduation] }

        var events: [CelebrationEvent] = []
        if let m = DaysMilestone.crossed(from: before.count, to: after.count),
           m != .formed, !(m.isMinor && smallMomentShownToday) {
            events.append(.milestone(m))
        }
        let now = HabitMath.consistency(completed: after, todayKey: todayKey)
        let then = HabitMath.consistency(completed: before, todayKey: todayKey)
        if now.counted >= levelMinimumCounted, let a = now.percent, let b = then.percent,
           let level = levels.last(where: { b < $0 && $0 <= a }) {
            events.append(.level(level))
        }
        if markedKey == todayKey, !smallMomentShownToday,
           let gap = HabitMath.comebackGap(completed: after, dayKey: todayKey),
           !(1...6).contains(where: { HabitMath.comebackGap(completed: after, dayKey: ContinuumDay.key(byAdding: -$0, to: todayKey)) != nil }) {
            events.append(.comeback(gap: gap))
        }
        return events
    }
}
```

`TileCelebration.init?(_:)` maps: milestone → value "\(n)", unit "day(s) done", captions first mark / it's real now / momentum / a week's worth / becoming you / few get here / a year of days, shareable unless minor; level → value "\(p)%", unit "consistent", captions half your days / three days in four / nine days in ten / every single day, shareable at 90+; comeback → "BACK" / "on it" / "didn't miss twice" (gap 1) or "picked it back up". Delete `StreakMilestone`, `FreezeSaveOverlay` and its preview from `CelebrationView.swift`; graduation card shows `.value("66", unit: "days done")`, message "Not in a row.\nYou just kept coming back."

- [ ] **Step 3: Run tests, commit** — `"Milestones count days done; levels and comebacks"`

### Task 4: Notifications

**Files:** `continuum/Services/NotificationManager.swift`, `Shared/HabitDataManager.swift` (NotificationID), `continuumWidget/continuumWidget.swift` (intent), tests.

- [ ] **Step 1: Tests** — rewrite `NotificationPlannerTests` around a helper that marks explicit days back, and `ReminderCopyTests` for the new lines:

```swift
    private func habit(done backs: [Int], reminderHour: Int = 9) -> Habit {
        let h = Habit(name: "Read", reminderEnabled: true, reminderHour: reminderHour)
        for back in backs { h.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -back, to: today)) }
        return h
    }
    private func alerts(_ items: [PlannedNotification]) -> [PlannedNotification] {
        items.filter { $0.identifier.hasPrefix(NotificationID.missAlertPrefix) }
    }

    @Test func morningReminderSaysWhatTodayDoesToTheNumber() {
        // 21 of 40 days, today open: 52% now, 22 of 41 = 53 if done
        let h = habit(done: Array(stride(from: 2, through: 40, by: 2)) + [1])
        let body = plan(h).first { $0.identifier == NotificationID.reminder(habitId: h.id, dayKey: today) }?.body ?? ""
        #expect(body.contains("53"))
    }
    @Test func dayAfterAMissGetsTheNeverMissTwiceAlert() {
        let items = alerts(plan(habit(done: [5, 4, 3, 2])))
        #expect(items.map(\.dayKey) == [today])
        #expect(items.first?.hour == 20)
        #expect(items.first?.title == "Read: never miss twice")
    }
    @Test func twoMissesInARowGetNoAlert() { #expect(alerts(plan(habit(done: [5, 4, 3]))).isEmpty) }
    @Test func openTodayArmsTomorrowsAlertAndDoneTodayDisarmsIt() {
        let tomorrow = ContinuumDay.key(byAdding: 1, to: today)
        #expect(alerts(plan(habit(done: [3, 2, 1]))).map(\.dayKey) == [tomorrow])
        #expect(alerts(plan(habit(done: [3, 2, 1, 0]))).isEmpty)
    }
    @Test func eveningReminderReplacesTheAlert() { #expect(alerts(plan(habit(done: [5, 4, 3, 2], reminderHour: 21))).isEmpty) }
    @Test func pastEightNoAlertTonight() { #expect(alerts(plan(habit(done: [5, 4, 3, 2]), hour: 20, minute: 30)).isEmpty) }
    @Test func unknownDaysGetNeutralText() {
        let later = plan(habit(done: [3, 2, 1])).filter { $0.dayKey != today && $0.identifier.hasPrefix(NotificationID.reminderPrefix) }
        #expect(later.allSatisfy { !$0.body.contains("%") })
    }
```

- [ ] **Step 2: Implement** — `NotificationID.missAlertPrefix = "streak-risk-"` (the 3.7 prefix, so its leftovers are recognised and replaced) and `missAlert(habitId:dayKey:)`; planner: reminder body from `reminderBody(completed:dayKey:hasRecentHistory:)` for settled days (today, or tomorrow when today is done), neutral lines otherwise; miss alert at 20:00 for today if yesterday missed and the day before done, for tomorrow if today is open and yesterday done, never when the reminder is at/after 20:00 or it's already past 20:00. Widget intent removes `reminder(today)`, `missAlert(today)` and `missAlert(tomorrow)` on completion.

- [ ] **Step 3: Run tests, commit** — `"Notifications: consistency copy, never-miss-twice alert"`

### Task 5: Home screen and card

**Files:** `continuum/Views/Components/ConsistencyViews.swift` (new), `continuum/ContentView.swift`, `continuum/Views/HabitCardView.swift`.

- [ ] **Step 1: `ConsistencyViews.swift`** — `TrendLabel(trend:accent:fontSize:suffix:)` (arrow.up/arrow.down, up in accent, down in white 40%) and `ConsistencyHeader(tally:trend:doneToday:habitCount:accent:)`: big percent (56pt heavy mono) with a 26pt "%", "CONSISTENT · LAST 66 DAYS" label, trend "this week" and "N of M today" on the right; hidden until a habit has a number.
- [ ] **Step 2: Card** — header row is name + ⋯; below it the percent (26pt heavy, "%" at 14pt) with `TrendLabel`, "Hold to start" when there's no number, a gold star for formed habits; grid cells before the first done day at white 3.5% (misses stay 8%); `onCompletion: (Bool, Int)` passes the marked day key; accessibility reads "87 percent consistent, up 4 this week"; menu "Share Streak" → "Share"; snowflake removed.
- [ ] **Step 3: ContentView** — insert the header above the grid; pooled `overall` tallies; `checkForMilestones(habit:completed:dayKey:)` diffs `before`/`after` via `MilestoneDetector`, shows graduation or the first tile event, keys the review prompt to days done; delete `previousStreaks/previousHealth/previousBest`, `initializeMilestoneTracking`, `autoApplyStreakFreezes`, `grantWeeklyStreakFreezes`, the freeze grant and `FreezeSave`.
- [ ] **Step 4: Build, run in the simulator, screenshot, look.** Commit — `"Home: consistency header and percentage-first cards"`

### Task 6: Stats, share card, widgets, copy

- [ ] Stats: hero percent + trend, "WEEK BY WEEK" 12 bars from `weeklyBlocks`, tiles DAYS DONE / ALL-TIME / CURRENT RUN / BEST RUN / PERFECT WEEKS, heatmap with pre-start days faint and no freeze legend, footer with days left to formed.
- [ ] Share card: percent hero, "CONSISTENT", trend, "LAST 66 DAYS · done/counted", days done, formed badge.
- [ ] Widgets: small (percent + trend), medium (pooled percent, per-habit percent), circular (percent in the ring), rectangular ("87% consistent · ↑4"); description updated.
- [ ] Onboarding (Consistency / Hold to Mark / The Grid / 66 Days, flame icon gone), walkthrough ("Your Number" with never-miss-twice), About cards, Settings footer and reorder labels.
- [ ] Build, look at every screen, commit.

### Task 7: Rebrand metadata

- [ ] `scripts/aso.json`: name "Continuum: Consistency Tracker", subtitle "Daily habits, no streak resets", keywords (≤100), promo text, description — drafted with the writing-voice skill and checked with slopcheck/vale.
- [ ] `scripts/whats-new.txt` for 3.8; `docs/ASO.md` updated; `README.md` intro.
- [ ] Commit.

### Task 8: Screenshots

- [ ] Rewrite `continuumTests/SeedShots.swift` for the consistency story (six habits, 70–95%, a few misses, upward trends, one habit at 65 days done and open today for the graduation shot).
- [ ] Capture on iPhone 16 Pro Max with `simctl status_bar override --time 9:41`, `FAKE_TILT` for the sheen.
- [ ] `scripts/caption-screenshots.py` composites captions (SF Mono) onto 1320x2868 canvases → `AppStoreScreenshots/3.8/NN_name.png`.
- [ ] Look at every output; commit.

### Task 9: Release prep

- [ ] Bump to 3.8 (build 9) in all 8 places; full test run; code review subagent on the diff; fix findings; commit.
- [ ] Stop before `release.yml` / `asc-submit.mjs --submit`: submission waits for Ryan.

---

## Self-review

- Spec coverage: number (T1), trend (T1), header/card (T5), stats/widgets/share/settings (T6), moments (T3, T5), notifications (T4), freezes (T2, T5), rebrand (T6 copy, T7), screenshots (T8), testing (every task, T9). Not-doing list honoured in T9.
- Types: `ConsistencyTally(done:counted:)`, `.percent`, `.fraction`, `HabitMath.consistency/consistencyWeekAgo/trend(now:weekAgo:)/allTime/weeklyBlocks/comebackGap`, `DaysMilestone`, `CelebrationEvent.isSmallMoment`, `NotificationID.missAlert(Prefix)` are used with the same names in every task.
- UI tasks (5–6) list structure rather than full view bodies on purpose: they get iterated against simulator screenshots, and code written ahead of that would be stale by the first look.

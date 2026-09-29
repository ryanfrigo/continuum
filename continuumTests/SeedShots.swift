import Testing
import Foundation
import SwiftData
@testable import continuum

/// Seeds the simulator's store for App Store screenshots. Not a test of
/// anything: run one with -only-testing, then launch the app. Days are
/// relative to today, so the numbers come out the same whenever it runs:
/// 82% pooled, up 5 this week, 4 of 6 done today.
@MainActor
private enum ScreenshotSeed {
    /// Name, first day (days back), missed days (days back), done today.
    /// Misses thin out over time and cluster 66–72 days back, the stretch
    /// that just left the window, so the trends point up.
    static let habits: [(name: String, start: Int, missed: [Int], doneToday: Bool)] = [
        ("Meditate", 140, [12, 31, 49, 67, 68, 70, 72, 81, 95, 110, 126], true),
        ("Read 30 Pages", 100, [9, 20, 27, 38, 46, 55, 61, 66, 67, 69, 70, 71, 72, 84, 91], true),
        // Its stats bars climb week by week, 42% to 100%
        ("Lift Heavy", 120, [17, 24, 29, 33, 38, 43, 47, 50, 54, 57, 61, 64, 67, 69, 71, 74, 76, 78, 80,
                             82, 83, 86, 89, 93, 97, 100, 104, 108, 113, 117], false),
        ("Journal", 90, [8, 17, 26, 33, 41, 48, 57, 63, 66, 68, 69, 71, 72, 80], true),
        // Young and improving: 53% and up 9, so the colour scale gets used
        ("No Phone in Bed", 40, [9, 12, 14, 16, 18, 19, 21, 22, 24, 25, 27, 28, 30, 31, 33, 34, 36, 37, 39], true),
        // Missed yesterday only: holding it today is a clean comeback
        ("Zone 2 Cardio", 110, [1, 9, 13, 16, 18, 22, 26, 29, 33, 37, 41, 44, 48, 51, 55, 58, 62, 74, 79, 86,
                                93, 99], false),
    ]

    /// Habits past 66 days done are formed, except `unformed` — which then
    /// graduates on its next hold, for the graduation shot.
    static func seed(unformed: Set<String> = []) throws {
        let ctx = continuumApp.sharedModelContainer.mainContext
        for habit in try ctx.fetch(FetchDescriptor<Habit>()) { ctx.delete(habit) }
        for mark in try ctx.fetch(FetchDescriptor<CompletionMark>()) { ctx.delete(mark) }

        let today = ContinuumDay.todayKey()
        for (order, spec) in habits.enumerated() {
            let habit = Habit(name: spec.name, order: order)
            habit.createdAt = ContinuumDay.storageDate(for: ContinuumDay.key(byAdding: -spec.start, to: today))
            ctx.insert(habit)
            let missed = Set(spec.missed)
            let days = (spec.doneToday ? 0 : 1)...spec.start
            habit.setCompletedKeys(Set(days.filter { !missed.contains($0) }.map {
                ContinuumDay.key(byAdding: -$0, to: today)
            }))
            if !unformed.contains(spec.name) { _ = habit.checkAndMarkGraduation() }
        }
        try ctx.save()

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(true, forKey: "hasCompletedWalkthrough")
        // Nothing pops over the shots: no reminder offer, no review sheet
        defaults.set(true, forKey: "hasAskedForReminders")
        defaults.set(21, forKey: "reviewRequestedForMilestone")
        defaults.set(0, forKey: "lastMinorMilestoneCelebrationKey")
        defaults.set(0, forKey: "lastPerfectDayCelebrationKey")
    }
}

@MainActor
@Test func seedForScreenshots() throws {
    try ScreenshotSeed.seed()
}

@MainActor
@Test func seedForGraduationScreenshot() throws {
    try ScreenshotSeed.seed(unformed: ["Zone 2 Cardio"])
}

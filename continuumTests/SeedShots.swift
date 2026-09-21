import Testing
import Foundation
import SwiftData
@testable import continuum

@MainActor
@Test func seedForScreenshots() throws {
    let ctx = continuumApp.sharedModelContainer.mainContext
    for h in try ctx.fetch(FetchDescriptor<Habit>()) { ctx.delete(h) }
    let today = ContinuumDay.todayKey()
    // Long, healthy histories so the grid reads as lived-in
    let plan: [(String, Int, Int)] = [
        ("Meditate", 0, 41), ("Read", 1, 23), ("Train", 2, 0),
        ("Cold Shower", 3, 12), ("No Phone After 10", 4, 31), ("Write", 5, 7),
    ]
    for (name, order, streak) in plan {
        let h = Habit(name: name)
        h.order = order
        ctx.insert(h)
        for back in 0..<streak { h.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -back, to: today)) }
        // a few older marks so the 66-day grid isn't a solid block
        for back in (streak + 2)...(streak + 14) where back % 3 != 0 {
            h.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -back, to: today))
        }
    }
    // Train sits on 20 days through yesterday and is NOT done today, so one
    // hold takes it to the 21-day milestone — that's the celebration shot.
    if let train = try ctx.fetch(FetchDescriptor<Habit>()).first(where: { $0.name == "Train" }) {
        train.setCompletedKeys([])
        for back in 1...20 { train.setCompleted(true, forDayKey: ContinuumDay.key(byAdding: -back, to: today)) }
    }
    try ctx.save()
    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    UserDefaults.standard.set(true, forKey: "hasCompletedWalkthrough")
}

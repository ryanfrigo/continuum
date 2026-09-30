import Foundation

/// Days-done milestones: total days marked, in any order. A count that only
/// goes up can't be lost, so a bad week never takes one back.
enum DaysMilestone: Int, CaseIterable {
    // Dense rewards early (days 1–7 decide retention), scarce later.
    case one = 1
    case three = 3
    case five = 5
    case seven = 7
    case twentyOne = 21
    case hundred = 100
    case year = 365

    /// Early milestones stay light: they share one slot a day across habits.
    var isMinor: Bool { rawValue <= 5 }

    /// The biggest milestone passed going from `before` to `after` days done.
    static func crossed(from before: Int, to after: Int) -> DaysMilestone? {
        allCases.last { before < $0.rawValue && $0.rawValue <= after }
    }
}

/// What a completion just earned.
///
/// Graduation is the once-per-habit, full-screen moment. Everything else
/// celebrates inside the habit's own tile.
enum CelebrationEvent: Equatable {
    case graduation
    case milestone(DaysMilestone)
    case level(Int)          // consistency crossed 50, 75, 90 or 100
    case comeback(gap: Int)  // marked after missing the day before

    /// Minor milestones and comebacks share one slot a day across habits, so
    /// someone with six habits gets one small card, not a queue.
    var isSmallMoment: Bool {
        switch self {
        case .milestone(let milestone): return milestone.isMinor
        case .comeback: return true
        case .graduation, .level: return false
        }
    }
}

/// The rules for which celebrations a completion earns, kept pure so they can
/// be tested. They diff the habit's completed days either side of the mark
/// instead of remembering "previous" values in view state, which is where
/// the old streak rules misfired.
enum MilestoneDetector {
    static let levels = [50, 75, 90, 100]
    /// Below this many counted days the percentage swings too much to celebrate.
    static let levelMinimumCounted = 14

    /// The highest level a tally has reached, once it has the history to mean it.
    static func level(of tally: ConsistencyTally) -> Int? {
        guard tally.counted >= levelMinimumCounted, let percent = tally.percent else { return nil }
        return levels.last { $0 <= percent }
    }

    /// Everything marking `markedKey` earned, highest first.
    static func events(
        before: Set<Int>,
        after: Set<Int>,
        markedKey: Int,
        todayKey: Int,
        isAlreadyGraduated: Bool,
        smallMomentShownToday: Bool,
        highestLevelCelebrated: Int
    ) -> [CelebrationEvent] {
        // Once per habit: 66 days in, 80% of them done. No crossing required,
        // so a habit that already qualifies graduates on its next completion.
        if HabitMath.isFormed(completed: after, todayKey: todayKey) && !isAlreadyGraduated {
            return [.graduation]
        }

        var events: [CelebrationEvent] = []

        if let milestone = DaysMilestone.crossed(from: before.count, to: after.count),
           !(milestone.isMinor && smallMomentShownToday) {
            events.append(.milestone(milestone))
        }

        // Each level once per habit. Looking for a crossing instead re-fired
        // whenever the denominator wobbled across a threshold, and never
        // reached 100: marking today adds a day to both sides of the fraction.
        if let level = level(of: HabitMath.consistency(completed: after, todayKey: todayKey)),
           level > highestLevelCelebrated {
            events.append(.level(level))
        }

        // Never miss twice, rewarded: today done after a miss. Once a week per
        // habit at most — an every-other-day rhythm shouldn't earn it daily.
        if markedKey == todayKey,
           !smallMomentShownToday,
           let gap = HabitMath.comebackGap(completed: after, dayKey: todayKey),
           !(1...6).contains(where: { back in
               HabitMath.comebackGap(completed: after, dayKey: ContinuumDay.key(byAdding: -back, to: todayKey)) != nil
           }) {
            events.append(.comeback(gap: gap))
        }

        return events
    }
}

/// A celebration rendered inside a habit tile.
struct TileCelebration: Equatable, Identifiable {
    let id: UUID
    let value: String        // "21"
    let unit: String         // "days done"
    let caption: String      // "becoming you"
    let isShareable: Bool    // offers the share card on tap

    /// Seconds on screen before it clears itself.
    static let duration: Double = 2.4

    init?(_ event: CelebrationEvent) {
        switch event {
        case .graduation:
            return nil   // full-screen, not a tile card
        case .milestone(let milestone):
            self.init(
                id: UUID(),
                value: "\(milestone.rawValue)",
                unit: milestone == .one ? "day done" : "days done",
                caption: Self.caption(for: milestone),
                isShareable: !milestone.isMinor
            )
        case .level(let percent):
            self.init(id: UUID(), value: "\(percent)%", unit: "consistent",
                      caption: Self.caption(forLevel: percent), isShareable: percent >= 90)
        case .comeback(let gap):
            self.init(id: UUID(), value: "BACK", unit: "on it",
                      caption: gap == 1 ? "didn't miss twice" : "picked it back up", isShareable: false)
        }
    }

    private init(id: UUID, value: String, unit: String, caption: String, isShareable: Bool) {
        self.id = id
        self.value = value
        self.unit = unit
        self.caption = caption
        self.isShareable = isShareable
    }

    /// Short enough for a 170pt tile.
    private static func caption(for milestone: DaysMilestone) -> String {
        switch milestone {
        case .one: return "first mark"
        case .three: return "it's real now"
        case .five: return "momentum"
        case .seven: return "a week's worth"
        case .twentyOne: return "three weeks' worth"
        case .hundred: return "triple digits"
        case .year: return "a year of days"
        }
    }

    /// What the percentage means in days.
    private static func caption(forLevel percent: Int) -> String {
        switch percent {
        case 100: return "every single day"
        case 90...: return "nine days in ten"
        case 75...: return "three days in four"
        default: return "half your days"
        }
    }
}

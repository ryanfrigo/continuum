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
    case level(Int)          // consistency crossed 50, 90 or 100
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
    /// No 75: 80 is strong, and that has its own moment.
    static let levels = [50, 90, 100]
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
        // Once per habit, the first time it's strong. No crossing required,
        // so a habit that already qualifies gets it on its next completion.
        if HabitMath.isStrong(completed: after, todayKey: todayKey) && !isAlreadyGraduated {
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

    /// `completed` and `todayKey` are the habit just after the mark, so the
    /// words can say what actually happened: days done is a count in any
    /// order, not a run, and a level shows the real number.
    init?(_ event: CelebrationEvent, completed: Set<Int>, todayKey: Int) {
        switch event {
        case .graduation:
            return nil   // full-screen, not a tile card
        case .milestone(let milestone):
            // Days from the first one done to today, so 7 done reads
            // "every day so far" only when it was
            let span = completed.min().map { ContinuumDay.daysBetween($0, todayKey) + 1 } ?? milestone.rawValue
            self.init(
                id: UUID(),
                value: "\(milestone.rawValue)",
                unit: milestone == .one ? "day done" : "days done",
                caption: Self.caption(for: milestone, overDays: span),
                isShareable: !milestone.isMinor
            )
        case .level(let level):
            let percent = HabitMath.consistency(completed: completed, todayKey: todayKey).percent ?? level
            self.init(id: UUID(), value: "\(max(percent, level))%", unit: "last 4 weeks",
                      caption: Self.caption(forLevel: level), isShareable: level >= 90)
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

    /// Short enough for a 170pt tile. Days done are counted in any order, so
    /// only a run with no gaps gets called one.
    static func caption(for milestone: DaysMilestone, overDays span: Int) -> String {
        if milestone == .one { return "first mark" }
        if span <= milestone.rawValue { return "every day so far" }
        return "in \(span) days"
    }

    /// What the level means in days. The tile shows the real number, which
    /// can be above the level it just reached.
    static func caption(forLevel level: Int) -> String {
        switch level {
        case 100: return "every single day"
        case 90...: return "nine days in ten"
        default: return "at least half your days"
        }
    }
}

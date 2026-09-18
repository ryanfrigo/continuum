import Foundation

/// What a completion just earned.
///
/// Graduation is the once-per-habit, full-screen moment. Everything else
/// celebrates inside the habit's own tile.
enum CelebrationEvent: Equatable {
    case graduation
    case milestone(StreakMilestone)
    case personalRecord(Int)
    case health(Int)
}

/// The rules for which celebrations a completion earns, kept pure so they can
/// be tested. They used to live inline in ContentView, where the "did we just
/// cross this?" comparisons were invisible and one of them misfired daily.
enum MilestoneDetector {
    /// Below this, a new best is just a normal day — every early completion
    /// would otherwise be a "record".
    static let personalRecordFloor = 7
    static let habitFormationDays = 66
    static let healthMilestones = [25, 50, 75, 100]

    static func events(
        previousStreak: Int,
        newStreak: Int,
        isAlreadyGraduated: Bool,
        allTimeBest: Int,
        previousHealth: Int,
        newHealth: Int,
        minorAlreadyShownToday: Bool
    ) -> [CelebrationEvent] {
        var events: [CelebrationEvent] = []

        if newStreak >= habitFormationDays, previousStreak < habitFormationDays, !isAlreadyGraduated {
            // Once per habit, ever. Without the graduation check, a stale
            // previousStreak re-fires this every day a formed habit is completed.
            events.append(.graduation)
        } else if let milestone = StreakMilestone.milestone(for: newStreak),
                  newStreak > previousStreak,
                  milestone != .habitFormed,
                  !(milestone.isMinor && minorAlreadyShownToday) {
            events.append(.milestone(milestone))
        }

        // A number that is already a milestone doesn't also get a "record" card.
        if newStreak > allTimeBest,
           allTimeBest >= personalRecordFloor,
           StreakMilestone.milestone(for: newStreak) == nil {
            events.append(.personalRecord(newStreak))
        }

        if let crossed = healthMilestones.first(where: { newHealth >= $0 && previousHealth < $0 }) {
            events.append(.health(crossed))
        }

        return events
    }
}

/// A celebration rendered inside a habit tile.
struct TileCelebration: Equatable, Identifiable {
    let id: UUID
    let value: String        // "21"
    let unit: String         // "days"
    let caption: String      // "becoming you"
    let isShareable: Bool    // big streaks offer the share card on tap

    /// Seconds on screen before it clears itself.
    static let duration: Double = 2.4

    init?(_ event: CelebrationEvent) {
        switch event {
        case .graduation:
            return nil   // full-screen, not a tile card
        case .milestone(let milestone):
            self.init(
                id: UUID(),
                value: milestone.title,
                unit: milestone.subtitle,
                caption: Self.caption(for: milestone),
                isShareable: !milestone.isMinor
            )
        case .personalRecord(let streak):
            self.init(id: UUID(), value: "\(streak)", unit: "days", caption: "personal record", isShareable: true)
        case .health(let percentage):
            self.init(id: UUID(), value: "\(percentage)", unit: "%", caption: "health", isShareable: false)
        }
    }

    private init(id: UUID, value: String, unit: String, caption: String, isShareable: Bool) {
        self.id = id
        self.value = value
        self.unit = unit
        self.caption = caption
        self.isShareable = isShareable
    }

    /// Short enough for a 170pt tile — the full-screen copy wraps to four lines there.
    private static func caption(for milestone: StreakMilestone) -> String {
        switch milestone {
        case .dayOne: return "first mark"
        case .dayThree: return "it's real now"
        case .dayFive: return "momentum"
        case .week: return "one week"
        case .threeWeeks: return "becoming you"
        case .habitFormed: return "habit formed"
        case .hundred: return "few get here"
        case .year: return "one year"
        }
    }
}

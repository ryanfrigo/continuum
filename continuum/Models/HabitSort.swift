import Foundation

/// How the home screen orders habits. Manual is the drag order from
/// Settings; the other two follow the consistency number and re-sort as it
/// moves. Habits without a number yet go last either way.
enum HabitSort: String, CaseIterable, Identifiable {
    case manual
    case mostConsistent
    case leastConsistent

    static let storageKey = "habitSort"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: return "Manual"
        case .mostConsistent: return "Most consistent first"
        case .leastConsistent: return "Least consistent first"
        }
    }

    func sorted(_ habits: [Habit]) -> [Habit] {
        let byOrder = habits.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
        guard self != .manual else { return byOrder }
        // Stable on the manual order, so ties keep the order people chose
        // (Keyed by position, not id: sync duplicates can share an id until deduped)
        let percents = byOrder.map { $0.consistency.percent }
        return byOrder.indices.sorted { a, b in
            switch (percents[a], percents[b]) {
            case let (x?, y?) where x != y:
                return self == .mostConsistent ? x > y : x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a < b
            }
        }.map { byOrder[$0] }
    }
}

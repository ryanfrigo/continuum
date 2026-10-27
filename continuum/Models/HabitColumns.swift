import Foundation

/// The home grid as two columns that keep their habits, so a card only ever
/// moves straight up, down or across. Each column is open habits first, then
/// done ones, and no done habit sits above an open one:
///
/// 1. `fall` — a habit drops onto (or rises off) the done pile in its own column.
/// 2. `rebalanceStep` — when a done card sits above an open one in the other
///    column, it swaps across with the open card beside it, then falls onto
///    the other column's pile.
struct HabitColumns: Equatable {
    var columns: [[UUID]] = [[], []]

    /// Open first, then done, dealt row by row: left, right, left, right.
    init(ordered: [UUID], isDone: (UUID) -> Bool) {
        let flat = ordered.filter { !isDone($0) } + ordered.filter(isDone)
        for (i, id) in flat.enumerated() { columns[i % 2].append(id) }
    }

    /// Row by row, the order the grid lays out.
    var rows: [UUID] {
        var out: [UUID] = []
        for (i, id) in columns[0].enumerated() {
            out.append(id)
            if i < columns[1].count { out.append(columns[1][i]) }
        }
        return out
    }

    func contains(_ id: UUID) -> Bool { columns.contains { $0.contains(id) } }

    /// Moves `id` to the edge of its column's done pile: on top of it if
    /// done, just above it if not. A card already on the right side stays.
    mutating func fall(_ id: UUID, isDone: (UUID) -> Bool) {
        for c in 0..<2 {
            guard let at = columns[c].firstIndex(of: id) else { continue }
            var column = columns[c]
            column.remove(at: at)
            let openCount = column.filter { !isDone($0) }.count
            let misplaced = isDone(id) ? at < openCount : at > openCount
            guard misplaced else { return }
            column.insert(id, at: openCount)
            columns[c] = column
            return
        }
    }

    /// The done card to move across next, if a done card sits higher than
    /// an open one in the other column: the top of that pile, which has an
    /// open card beside it. A bottom row that's part done is fine.
    func imbalance(isDone: (UUID) -> Bool) -> (column: Int, row: Int)? {
        let open = columns.map { $0.filter { !isDone($0) }.count }
        for heavy in 0..<2 where columns[heavy].count > open[heavy] {
            // Its top done card is at row open[heavy]; the other column's
            // lowest open card is at row open[other] - 1
            // Only a done card swapping with an open one: a card marked done
            // but not settled yet leaves a column out of order, and swapping
            // two open cards would never close the gap
            let row = open[heavy], light = 1 - heavy
            if row < open[light] - 1, isDone(columns[heavy][row]), !isDone(columns[light][row]) {
                return (heavy, row)
            }
        }
        return nil
    }

    /// One move across. Returns the done card that moved, or nil when
    /// already balanced.
    @discardableResult
    mutating func rebalanceStep(isDone: (UUID) -> Bool) -> UUID? {
        guard let (heavy, row) = imbalance(isDone: isDone) else { return nil }
        let light = 1 - heavy
        let doneID = columns[heavy][row]
        columns[heavy][row] = columns[light][row]
        columns[light][row] = doneID
        fall(doneID, isDone: isDone)
        return doneID
    }

    /// Cards that would change both row and column getting to `other`:
    /// they can't slide there in a straight line.
    func diagonalMoves(to other: HabitColumns) -> [UUID] {
        func spots(_ grid: HabitColumns) -> [UUID: (Int, Int)] {
            var out: [UUID: (Int, Int)] = [:]
            for (c, column) in grid.columns.enumerated() {
                for (r, id) in column.enumerated() { out[id] = (c, r) }
            }
            return out
        }
        let before = spots(self), after = spots(other)
        return before.compactMap { id, from in
            guard let to = after[id], to.0 != from.0, to.1 != from.1 else { return nil }
            return id
        }
    }
}

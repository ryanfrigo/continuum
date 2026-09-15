import Foundation
import SwiftData

// MARK: - Per-day sync ledger
//
// `Habit.completedDates` is one array attribute, so CloudKit syncs it
// last-writer-wins: complete Monday on the phone and Tuesday on the iPad and
// one device's write erases the other's. Each (habit, day) change is also
// recorded here as its own record, so edits to different days merge, and a
// same-day conflict resolves by latest edit instead of by whole history.
//
// The array stays the in-app working copy (every read path, the widget, and
// pre-3.4 devices use it) and is rebuilt from the ledger on reconcile.
// Same CloudKit rules as Habit: no unique constraints, defaults everywhere.
@Model
final class CompletionMark {
    /// Random, synced tiebreaker so every device picks the same survivor
    /// when it deletes duplicate marks.
    var markId: UUID = UUID()
    var habitId: UUID = UUID()
    var dayKey: Int = 0
    /// false is a tombstone: an un-completion must sync too, or another
    /// device's stale array would resurrect the day.
    var isCompleted: Bool = true
    var modifiedAt: Date = Date()

    init(habitId: UUID, dayKey: Int, isCompleted: Bool, modifiedAt: Date = Date()) {
        self.markId = UUID()
        self.habitId = habitId
        self.dayKey = dayKey
        self.isCompleted = isCompleted
        self.modifiedAt = modifiedAt
    }
}

/// Value copy of a mark, so the merge rules are pure and unit-tested.
struct MarkSnapshot: Equatable {
    let markId: UUID
    let dayKey: Int
    let isCompleted: Bool
    let modifiedAt: Date
}

enum CompletionLedger {

    struct Merge: Equatable {
        /// The habit's true completed days.
        let completed: Set<Int>
        /// Redundant marks every device agrees to delete.
        let duplicateMarkIds: Set<UUID>
    }

    static func merge(arrayKeys: Set<Int>, marks: [MarkSnapshot]) -> Merge {
        var winners: [Int: MarkSnapshot] = [:]
        var duplicates = Set<UUID>()

        for mark in marks {
            guard let current = winners[mark.dayKey] else {
                winners[mark.dayKey] = mark
                continue
            }
            if beats(mark, current) {
                duplicates.insert(current.markId)
                winners[mark.dayKey] = mark
            } else {
                duplicates.insert(mark.markId)
            }
        }

        // Days a 3.4 device edited follow the ledger. Days nobody edited since
        // 3.4 (older history, or edits from a 3.3 device, which can only write
        // the array) follow the array, exactly as 3.3 did. Recording those as
        // marks would make them un-removable from a 3.3 device.
        let marked = Set(winners.keys)
        let completedByMarks = Set(winners.values.filter(\.isCompleted).map(\.dayKey))
        return Merge(
            completed: completedByMarks.union(arrayKeys.subtracting(marked)),
            duplicateMarkIds: duplicates
        )
    }

    /// Latest edit wins; a clock tie keeps the completion; then the lower
    /// markId, so the order is identical on every device.
    private static func beats(_ a: MarkSnapshot, _ b: MarkSnapshot) -> Bool {
        if a.modifiedAt != b.modifiedAt { return a.modifiedAt > b.modifiedAt }
        if a.isCompleted != b.isCompleted { return a.isCompleted }
        return a.markId.uuidString < b.markId.uuidString
    }

    /// Bring every habit's array in line with the ledger. Idempotent — saves
    /// only when something changed, so it's safe on every activation and
    /// remote-change notification. Returns true if anything changed.
    @discardableResult
    static func reconcile(habits: [Habit], in context: ModelContext) -> Bool {
        guard let allMarks = try? context.fetch(FetchDescriptor<CompletionMark>()) else { return false }
        let marksByHabit = Dictionary(grouping: allMarks, by: \.habitId)
        var changed = false

        for habit in habits {
            let marks = marksByHabit[habit.id] ?? []
            let result = merge(
                arrayKeys: habit.completedDayKeys,
                marks: marks.map {
                    MarkSnapshot(markId: $0.markId, dayKey: $0.dayKey, isCompleted: $0.isCompleted, modifiedAt: $0.modifiedAt)
                }
            )

            for mark in marks where result.duplicateMarkIds.contains(mark.markId) {
                context.delete(mark)
            }
            let arrayIsStale = result.completed != habit.completedDayKeys
            if arrayIsStale {
                habit.completedDatesArray = result.completed.sorted().map { ContinuumDay.storageDate(for: $0) }
            }
            if arrayIsStale || !result.duplicateMarkIds.isEmpty {
                changed = true
            }
        }

        if changed { try? context.save() }
        return changed
    }

    /// Delete a habit's ledger along with the habit.
    static func deleteMarks(for habitIds: Set<UUID>, in context: ModelContext) {
        guard let marks = try? context.fetch(FetchDescriptor<CompletionMark>()) else { return }
        for mark in marks where habitIds.contains(mark.habitId) {
            context.delete(mark)
        }
    }
}

import Foundation
import SwiftData

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var completedDates: [Date]

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), completedDates: [Date] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.completedDates = completedDates.map { Habit.startOfDay($0) }
    }

    // MARK: - Helpers

    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private var completedSet: Set<Date> {
        Set(completedDates.map { Habit.startOfDay($0) })
    }

    var isCompletedToday: Bool {
        let today = Habit.startOfDay(Date())
        return completedSet.contains(today)
    }

    func toggleCompletion(for date: Date = Date()) {
        let day = Habit.startOfDay(date)
        if let idx = completedDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: day) }) {
            completedDates.remove(at: idx)
        } else {
            completedDates.append(day)
        }
    }

    func currentStreak(asOf date: Date = Date()) -> Int {
        let set = completedSet
        var count = 0
        var cursor = Habit.startOfDay(date)
        while set.contains(cursor) {
            count += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = Habit.startOfDay(prev)
        }
        return count
    }

    func historyCompletionFlags(daysBack: Int = 56, asOf date: Date = Date()) -> [Bool] {
        let set = completedSet
        let start = Habit.startOfDay(date)
        return (0..<daysBack).reversed().map { offset in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: start) ?? start
            return set.contains(Habit.startOfDay(d))
        }
    }

    // MARK: - Mutations

    /// Remove all completion history.
    func resetProgress() {
        completedDates.removeAll(keepingCapacity: true)
    }

    /// Mark the most recent `count` days (including today) as completed.
    /// If a day is already marked complete it will not be duplicated.
    func addRecentDays(_ count: Int, asOf date: Date = Date()) {
        guard count > 0 else { return }
        let base = Habit.startOfDay(date)
        for delta in 0..<count {
            if let d = Calendar.current.date(byAdding: .day, value: -delta, to: base) {
                let day = Habit.startOfDay(d)
                if !completedSet.contains(day) {
                    completedDates.append(day)
                }
            }
        }
    }

    /// Force the current streak (ending today) to be exactly `target` days long.
    /// This ensures all days in the last `target`-1 offsets are completed, and the
    /// day at offset `target` is cleared to break any longer chain.
    func setCurrentStreak(_ target: Int, asOf date: Date = Date()) {
        let clamped = max(0, min(1000, target))
        let today = Habit.startOfDay(date)

        // Ensure the last `clamped` days (including today) are completed
        if clamped > 0 {
            for delta in 0..<clamped {
                if let d = Calendar.current.date(byAdding: .day, value: -delta, to: today) {
                    let day = Habit.startOfDay(d)
                    if !completedSet.contains(day) {
                        completedDates.append(day)
                    }
                }
            }
        } else {
            // clamped == 0: make sure today is not completed
            if let idx = completedDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
                completedDates.remove(at: idx)
            }
        }

        // Break any longer chain by ensuring the day just before the earliest streak day is not completed
        if let breakDay = Calendar.current.date(byAdding: .day, value: -clamped, to: today) {
            let bd = Habit.startOfDay(breakDay)
            if let idx = completedDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: bd) }) {
                completedDates.remove(at: idx)
            }
        }
    }
}







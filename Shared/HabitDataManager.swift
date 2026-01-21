import Foundation
import WidgetKit
#if canImport(SwiftData)
import SwiftData
#endif

class HabitDataManager {
    static let shared = HabitDataManager()
    static let appGroupIdentifier = "group.com.orionlabs.continuum"
    
    private init() {}
    
    // MARK: - Data Persistence
    
    func saveSelectedHabitId(_ habitId: UUID?) {
        let userDefaults = UserDefaults(suiteName: Self.appGroupIdentifier)
        if let habitId = habitId {
            userDefaults?.set(habitId.uuidString, forKey: "selectedHabitId")
        } else {
            userDefaults?.removeObject(forKey: "selectedHabitId")
        }
    }
    
    func getSelectedHabitId() -> UUID? {
        let userDefaults = UserDefaults(suiteName: Self.appGroupIdentifier)
        guard let habitIdString = userDefaults?.string(forKey: "selectedHabitId") else {
            return nil
        }
        return UUID(uuidString: habitIdString)
    }
    
    // MARK: - Widget Timeline Updates
    
    func updateWidgetTimeline() {
        WidgetCenter.shared.reloadTimelines(ofKind: "continuumWidget")
    }
    
    // MARK: - Habit Data Access
    
    func getAllHabitIds() -> [UUID] {
        let userDefaults = UserDefaults(suiteName: Self.appGroupIdentifier)
        guard let data = userDefaults?.data(forKey: "allHabitIds") else {
            return []
        }
        do {
            let ids = try JSONDecoder().decode([String].self, from: data)
            return ids.compactMap { UUID(uuidString: $0) }
        } catch {
            return []
        }
    }
    
    func saveAllHabitIds(_ habitIds: [UUID]) {
        let userDefaults = UserDefaults(suiteName: Self.appGroupIdentifier)
        let ids = habitIds.map { $0.uuidString }
        do {
            let data = try JSONEncoder().encode(ids)
            userDefaults?.set(data, forKey: "allHabitIds")
        } catch {
            print("Failed to encode habit IDs: \(error)")
        }
    }
    
    func getSelectedHabitData() -> HabitData? {
        // First try to get a selected habit
        if let habitId = getSelectedHabitId(),
           let habitData = getHabitData(for: habitId) {
            return habitData
        }
        
        // Otherwise, get the first habit by order
        let allIds = getAllHabitIds()
        for habitId in allIds {
            if let habitData = getHabitData(for: habitId) {
                return habitData
            }
        }
        
        return nil
    }
    
    func getHabitData(for habitId: UUID) -> HabitData? {
        let userDefaults = UserDefaults(suiteName: Self.appGroupIdentifier)
        guard let data = userDefaults?.data(forKey: "habitData_\(habitId.uuidString)") else {
            return nil
        }
        
        do {
            let habitData = try JSONDecoder().decode(HabitData.self, from: data)
            return habitData
        } catch {
            print("Failed to decode habit data: \(error)")
            return nil
        }
    }
    
    func saveHabitData(_ habitData: HabitData) {
        let userDefaults = UserDefaults(suiteName: Self.appGroupIdentifier)
        
        do {
            let data = try JSONEncoder().encode(habitData)
            userDefaults?.set(data, forKey: "habitData_\(habitData.id.uuidString)")
        } catch {
            print("Failed to encode habit data: \(error)")
        }
    }
}

// MARK: - Habit Data Structure for Widget

struct HabitData: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let completedDates: [Date]
    
    init(id: UUID, name: String, createdAt: Date, completedDates: [Date]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.completedDates = completedDates
    }

    #if canImport(SwiftData)
    init(from habit: Habit) {
        self.id = habit.id
        self.name = habit.name
        self.createdAt = habit.createdAt
        self.completedDates = habit.completedDates
    }
    #endif
    
    // MARK: - Computed Properties
    
    private static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    var isCompletedToday: Bool {
        let today = Self.startOfDay(Date())
        return completedDates.contains { Calendar.current.isDate(Self.startOfDay($0), inSameDayAs: today) }
    }
    
    func currentStreak(asOf date: Date = Date()) -> Int {
        let set = Set(completedDates.map { Self.startOfDay($0) })
        var count = 0
        var cursor = Self.startOfDay(date)
        while set.contains(cursor) {
            count += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = Self.startOfDay(prev)
        }
        return count
    }
    
    func historyCompletionFlags(daysBack: Int = 49, asOf date: Date = Date()) -> [Bool] {
        let set = Set(completedDates.map { Self.startOfDay($0) })
        let start = Self.startOfDay(date)
        return (0..<daysBack).reversed().map { offset in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: start) ?? start
            return set.contains(Self.startOfDay(d))
        }
    }
}

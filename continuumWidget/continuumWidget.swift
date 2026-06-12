import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct HabitEntry: TimelineEntry {
    let date: Date
    let habits: [HabitData]
    let overallHealth: Double
}

// MARK: - Widget Timeline Provider

struct HabitProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: Date(), habits: [], overallHealth: 0.0)
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> Void) {
        let habits = HabitDataManager.shared.loadAllHabitData()
        let health = habits.isEmpty ? 0.0 : habits.reduce(0.0) { $0 + $1.habitHealth } / Double(habits.count)
        completion(HabitEntry(date: Date(), habits: habits, overallHealth: health))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) {
        let habits = HabitDataManager.shared.loadAllHabitData()
        let health = habits.isEmpty ? 0.0 : habits.reduce(0.0) { $0 + $1.habitHealth } / Double(habits.count)
        let entry = HabitEntry(date: Date(), habits: habits, overallHealth: health)
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - Small Widget — Single Habit Card

struct SmallWidgetView: View {
    let habit: HabitData?

    private var health: Double { habit?.habitHealth ?? 0.0 }
    private var streak: Int { habit?.currentStreak ?? 0 }
    private var color: Color { healthColor(health) }

    private var flags: [Bool] {
        guard let h = habit else { return Array(repeating: false, count: 66) }
        var r = h.historyCompletionFlags(daysBack: 66)
        while r.count < 66 { r.append(false) }
        return Array(r.prefix(66).reversed())
    }

    var body: some View {
        if let habit {
            VStack(alignment: .leading, spacing: 0) {
                // Name + health
                HStack(alignment: .top) {
                    Text(habit.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 2.5)
                        Circle()
                            .trim(from: 0, to: health)
                            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .shadow(color: color.opacity(0.4), radius: 3)
                        Text("\(Int(health * 100))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                    }
                    .frame(width: 28, height: 28)
                }

                // Streak
                HStack(spacing: 3) {
                    if streak > 0 {
                        Circle().fill(color).frame(width: 4, height: 4)
                            .shadow(color: color, radius: 2)
                        Text("\(streak)d streak")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    } else {
                        Text("Hold to start")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.top, 2)

                Spacer(minLength: 4)

                // 66-day grid
                MiniGrid(flags: flags, color: color, columns: 11, rows: 6, dotSpacing: 2)

                // Today badge
                if habit.isCompletedToday {
                    HStack {
                        Spacer()
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .heavy))
                            Text("DONE")
                                .font(.system(size: 7, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(color.opacity(0.12)))
                    }
                    .padding(.top, 3)
                }
            }
            .padding(4)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus.circle")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Color.orange.opacity(0.4))
            Text("Add a habit")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Medium Widget — Multi-Habit Grid View

struct MediumWidgetView: View {
    let habits: [HabitData]

    private var completedCount: Int { habits.filter { $0.isCompletedToday }.count }
    private var allDone: Bool { !habits.isEmpty && completedCount == habits.count }
    private var overallHealth: Double {
        guard !habits.isEmpty else { return 0.0 }
        return habits.reduce(0.0) { $0 + $1.habitHealth } / Double(habits.count)
    }

    var body: some View {
        if habits.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Color.orange.opacity(0.4))
                Text("Add habits to get started")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // Compact header
                HStack {
                    // Today counter
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(completedCount)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(allDone ? goldColor : healthColor(overallHealth))
                        Text("/\(habits.count)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.25))
                        Text(allDone ? "perfect" : "today")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.leading, 2)
                    }

                    Spacer()

                    // Health ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: overallHealth)
                            .stroke(healthColor(overallHealth), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(overallHealth * 100))%")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(healthColor(overallHealth))
                    }
                    .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
                .padding(.bottom, 2)

                // Habit cards with grids
                HStack(spacing: 6) {
                    ForEach(Array(habits.prefix(3).enumerated()), id: \.element.id) { _, habit in
                        MediumHabitCard(habit: habit)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
        }
    }

    private var goldColor: Color {
        Color(hue: 0.12, saturation: 0.8, brightness: 0.95)
    }
}

// MARK: - Medium Widget Habit Card

private struct MediumHabitCard: View {
    let habit: HabitData

    private var health: Double { habit.habitHealth }
    private var color: Color { healthColor(health) }
    private var streak: Int { habit.currentStreak }

    private var flags: [Bool] {
        var r = habit.historyCompletionFlags(daysBack: 66)
        while r.count < 66 { r.append(false) }
        return Array(r.prefix(66).reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Name
            HStack(spacing: 4) {
                if habit.isCompletedToday {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(color)
                }
                Text(habit.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            // Streak
            if streak > 0 {
                Text("\(streak)d")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.7))
            }

            Spacer(minLength: 2)

            // Mini grid — compact version
            MiniGrid(flags: flags, color: color, columns: 11, rows: 6, dotSpacing: 1.5)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(habit.isCompletedToday ? 0.25 : 0.08), lineWidth: 1)
        )
    }
}

// MARK: - Reusable Mini Grid

private struct MiniGrid: View {
    let flags: [Bool]
    let color: Color
    let columns: Int
    let rows: Int
    let dotSpacing: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let dotSize = floor((w - CGFloat(columns - 1) * dotSpacing) / CGFloat(columns))

            VStack(spacing: dotSpacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: dotSpacing) {
                        ForEach(0..<columns, id: \.self) { col in
                            let idx = row * columns + col
                            let filled = idx < flags.count && flags[idx]
                            let isToday = idx == 0

                            RoundedRectangle(cornerRadius: max(1, dotSize * 0.15))
                                .fill(filled ? color : Color.white.opacity(isToday ? 0.12 : 0.05))
                                .frame(width: dotSize, height: dotSize)
                        }
                    }
                }
            }
        }
        .aspectRatio(CGFloat(columns) / CGFloat(rows) * 1.0, contentMode: .fit)
    }
}

// MARK: - Widget Configuration

struct ContinuumWidget: Widget {
    let kind: String = "continuumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
            ContinuumWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Continuum")
        .description("Track your daily habit streaks")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ContinuumWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: HabitEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(habit: entry.habits.first)
            case .systemMedium:
                MediumWidgetView(habits: entry.habits)
            default:
                SmallWidgetView(habit: entry.habits.first)
            }
        }
        .containerBackground(for: .widget) {
            Color(red: 0.08, green: 0.09, blue: 0.11)
        }
    }
}

// MARK: - Color Helper

private func healthColor(_ health: Double) -> Color {
    let clamped = max(0, min(1, health))
    if clamped <= 0.5 {
        let t = clamped / 0.5
        let hue = 30.0/360.0 + (140.0/360.0 - 30.0/360.0) * t
        return Color(hue: hue, saturation: 0.85, brightness: 0.95)
    } else {
        let t = (clamped - 0.5) / 0.5
        let hue = 140.0/360.0 + (175.0/360.0 - 140.0/360.0) * t
        return Color(hue: hue, saturation: 0.75, brightness: 0.9)
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    ContinuumWidget()
} timeline: {
    HabitEntry(
        date: Date(),
        habits: [
            HabitData(
                id: UUID(),
                name: "Cold Shower",
                createdAt: Date().addingTimeInterval(-30 * 86400),
                completedDates: (0..<20).map { Date().addingTimeInterval(-Double($0) * 86400) }
            )
        ],
        overallHealth: 0.65
    )
}

#Preview(as: .systemMedium) {
    ContinuumWidget()
} timeline: {
    HabitEntry(
        date: Date(),
        habits: [
            HabitData(id: UUID(), name: "Cold Shower", createdAt: Date(),
                      completedDates: (0..<15).map { Date().addingTimeInterval(-Double($0) * 86400) }),
            HabitData(id: UUID(), name: "Meditate", createdAt: Date(),
                      completedDates: (0..<8).map { Date().addingTimeInterval(-Double($0) * 86400) }),
            HabitData(id: UUID(), name: "Run 5K", createdAt: Date(),
                      completedDates: [Date()])
        ],
        overallHealth: 0.45
    )
}

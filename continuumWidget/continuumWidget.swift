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
        HabitEntry(
            date: Date(),
            habits: [],
            overallHealth: 0.0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> Void) {
        let habits = HabitDataManager.shared.loadAllHabitData()
        let overallHealth = calculateOverallHealth(habits: habits)
        let entry = HabitEntry(date: Date(), habits: habits, overallHealth: overallHealth)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) {
        let habits = HabitDataManager.shared.loadAllHabitData()
        let overallHealth = calculateOverallHealth(habits: habits)
        let entry = HabitEntry(date: Date(), habits: habits, overallHealth: overallHealth)

        // Update at midnight each day
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func calculateOverallHealth(habits: [HabitData]) -> Double {
        guard !habits.isEmpty else { return 0.0 }
        let total = habits.reduce(0.0) { $0 + $1.habitHealth }
        return total / Double(habits.count)
    }
}

// MARK: - Widget Views

struct OverallHealthWidgetView: View {
    let habits: [HabitData]
    let overallHealth: Double

    private var healthColor: Color {
        let hueOrange: Double = 30.0 / 360.0
        let hueGreen: Double = 140.0 / 360.0
        let hueCyan: Double = 175.0 / 360.0

        let clamped = max(0, min(1, overallHealth))

        if clamped <= 0.5 {
            let t = clamped / 0.5
            let hue = hueOrange + (hueGreen - hueOrange) * t
            return Color(hue: hue, saturation: 0.85, brightness: 0.95)
        } else {
            let t = (clamped - 0.5) / 0.5
            let hue = hueGreen + (hueCyan - hueGreen) * t
            return Color(hue: hue, saturation: 0.75, brightness: 0.9)
        }
    }

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(red: 0.06, green: 0.07, blue: 0.09))

            VStack(spacing: 12) {
                // Health ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: overallHealth)
                        .stroke(healthColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: healthColor.opacity(0.6), radius: 8)

                    VStack(spacing: 2) {
                        Text("\(Int(overallHealth * 100))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(healthColor)

                        Text("health")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }

                VStack(spacing: 4) {
                    Text("Overall Health")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("\(habits.count) habits")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .padding()
        }
    }
}

struct HabitsListWidgetView: View {
    let habits: [HabitData]

    private func healthColor(for health: Double) -> Color {
        let hueOrange: Double = 30.0 / 360.0
        let hueGreen: Double = 140.0 / 360.0
        let hueCyan: Double = 175.0 / 360.0

        let clamped = max(0, min(1, health))

        if clamped <= 0.5 {
            let t = clamped / 0.5
            let hue = hueOrange + (hueGreen - hueOrange) * t
            return Color(hue: hue, saturation: 0.85, brightness: 0.95)
        } else {
            let t = (clamped - 0.5) / 0.5
            let hue = hueGreen + (hueCyan - hueGreen) * t
            return Color(hue: hue, saturation: 0.75, brightness: 0.9)
        }
    }

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(red: 0.06, green: 0.07, blue: 0.09))

            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text("Today")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(habits.filter { $0.isCompletedToday }.count)/\(habits.count)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Habits list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(habits.prefix(3), id: \.id) { habit in
                        HStack(spacing: 8) {
                            // Completion indicator
                            ZStack {
                                Circle()
                                    .fill(habit.isCompletedToday ? healthColor(for: habit.habitHealth) : Color.white.opacity(0.1))
                                    .frame(width: 20, height: 20)

                                if habit.isCompletedToday {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.black)
                                }
                            }

                            // Habit name
                            Text(habit.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Spacer()

                            // Streak
                            if habit.currentStreak > 0 {
                                HStack(spacing: 3) {
                                    Text("\(habit.currentStreak)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(healthColor(for: habit.habitHealth))
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(healthColor(for: habit.habitHealth))
                                }
                            }
                        }
                    }

                    if habits.count > 3 {
                        Text("+\(habits.count - 3) more")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Widget Configuration

struct ContinuumWidget: Widget {
    let kind: String = "continuumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
            if #available(iOS 17.0, *) {
                ContinuumWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ContinuumWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Continuum")
        .description("Track your habits and overall health")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ContinuumWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: HabitEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            OverallHealthWidgetView(habits: entry.habits, overallHealth: entry.overallHealth)
        case .systemMedium:
            HabitsListWidgetView(habits: entry.habits)
        default:
            OverallHealthWidgetView(habits: entry.habits, overallHealth: entry.overallHealth)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    ContinuumWidget()
} timeline: {
    HabitEntry(
        date: Date(),
        habits: [
            HabitData(
                id: UUID(),
                name: "Exercise",
                createdAt: Date(),
                completedDates: [Date()]
            ),
            HabitData(
                id: UUID(),
                name: "Read",
                createdAt: Date(),
                completedDates: []
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
            HabitData(
                id: UUID(),
                name: "Exercise",
                createdAt: Date(),
                completedDates: [Date()]
            ),
            HabitData(
                id: UUID(),
                name: "Read",
                createdAt: Date(),
                completedDates: []
            ),
            HabitData(
                id: UUID(),
                name: "Meditate",
                createdAt: Date(),
                completedDates: [Date()]
            )
        ],
        overallHealth: 0.65
    )
}

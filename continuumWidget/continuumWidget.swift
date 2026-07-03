import WidgetKit
import SwiftUI
import AppIntents
import UserNotifications

// MARK: - Toggle Habit Intent (interactive widget, iOS 17+)
//
// Runs in the widget extension process. It can't touch SwiftData directly,
// so it: (1) updates the shared app-group snapshot optimistically so the
// widget UI responds instantly, and (2) queues the desired end state for the
// app to reconcile into SwiftData on next activation.
struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Habit"
    static var description = IntentDescription("Mark a habit as done for today.")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Habit ID")
    var habitIdString: String

    init() {}

    init(habitId: UUID) {
        self.habitIdString = habitId.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let habitId = UUID(uuidString: habitIdString),
              let habitData = HabitDataManager.shared.getHabitData(for: habitId) else {
            return .result()
        }

        let (updated, nowCompleted) = habitData.togglingToday()
        HabitDataManager.shared.saveHabitData(updated)
        HabitDataManager.shared.appendPendingToggle(
            habitId: habitId,
            dayKey: ContinuumDay.todayKey(),
            completed: nowCompleted
        )
        HabitDataManager.shared.updateWidgetTimeline()

        // Silence today's nudges — being reminded at 9pm about a habit
        // completed from the lock screen at 9am gets notifications disabled.
        // (IDs mirror NotificationManager's notificationId/streakAtRiskNotificationId.)
        if nowCompleted {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
                "habit-reminder-\(habitId.uuidString)-day0",
                "streak-risk-\(habitId.uuidString)",
            ])
        }
        return .result()
    }
}

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
        // "Now + 24h" lands in the PAST hour on a 25-hour DST-fall day;
        // stepping a calendar day from today's start is always tomorrow.
        let todayStart = Calendar.current.startOfDay(for: Date())
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: todayStart)
            ?? Date().addingTimeInterval(86400)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - Complete Button (shared by widget sizes)

struct CompleteButton: View {
    let habit: HabitData
    let color: Color
    var compact: Bool = false

    var body: some View {
        Button(intent: ToggleHabitIntent(habitId: habit.id)) {
            if habit.isCompletedToday {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: compact ? 6 : 7, weight: .heavy))
                    if !compact {
                        Text("DONE")
                            .font(.system(size: 7, weight: .heavy, design: .rounded))
                    }
                }
                .foregroundStyle(color)
                .padding(.horizontal, compact ? 4 : 6)
                .padding(.vertical, compact ? 4 : 3)
                .background(Capsule().fill(color.opacity(0.15)))
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "circle")
                        .font(.system(size: compact ? 8 : 9, weight: .bold))
                    if !compact {
                        Text("MARK DONE")
                            .font(.system(size: 7, weight: .heavy, design: .rounded))
                    }
                }
                .foregroundStyle(color.opacity(0.9))
                .padding(.horizontal, compact ? 4 : 6)
                .padding(.vertical, compact ? 4 : 3)
                .background(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
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
                        Text("Tap to start")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.top, 2)

                Spacer(minLength: 4)

                // 66-day grid
                MiniGrid(flags: flags, color: color, columns: 11, rows: 6, dotSpacing: 2)

                // Complete button — interactive, no app launch needed
                HStack {
                    Spacer()
                    CompleteButton(habit: habit, color: color)
                }
                .padding(.top, 3)
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
            // Name + complete button
            HStack(spacing: 4) {
                Text(habit.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CompleteButton(habit: habit, color: color, compact: true)
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

// MARK: - Lock Screen Widgets (iOS 17 accessories)

struct AccessoryCircularView: View {
    let habit: HabitData?

    var body: some View {
        if let habit {
            ZStack {
                AccessoryWidgetBackground()
                Circle()
                    .trim(from: 0, to: max(0.04, habit.habitHealth))
                    .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)

                if habit.isCompletedToday {
                    VStack(spacing: 0) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                        Text("\(habit.currentStreak)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                } else {
                    VStack(spacing: 0) {
                        Text("\(habit.currentStreak)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("DAYS")
                            .font(.system(size: 7, weight: .semibold, design: .rounded))
                            .opacity(0.7)
                    }
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "plus")
            }
        }
    }
}

struct AccessoryRectangularView: View {
    let habits: [HabitData]

    private var completedCount: Int { habits.filter { $0.isCompletedToday }.count }

    var body: some View {
        if let first = habits.first {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: first.isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11, weight: .bold))
                    Text(first.name)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
                Text("\(first.currentStreak)-day streak")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.8)
                if habits.count > 1 {
                    Text("\(completedCount)/\(habits.count) done today")
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Add a habit in Continuum")
                .font(.system(size: 12, weight: .medium))
        }
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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct ContinuumWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: HabitEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularView(habit: entry.habits.first)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            AccessoryRectangularView(habits: entry.habits)
                .containerBackground(for: .widget) { Color.clear }
        case .systemMedium:
            MediumWidgetView(habits: entry.habits)
                .containerBackground(for: .widget) {
                    Color(red: 0.08, green: 0.09, blue: 0.11)
                }
        default:
            SmallWidgetView(habit: entry.habits.first)
                .containerBackground(for: .widget) {
                    Color(red: 0.08, green: 0.09, blue: 0.11)
                }
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

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
    static var title: LocalizedStringResource = "Mark Habit Done"
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
        // IDs are keyed by date, so this hits today's requests even if the app
        // hasn't run today. An un-complete is restored when the app next syncs.
        // Today done also means tomorrow doesn't follow a miss.
        if nowCompleted {
            let todayKey = ContinuumDay.todayKey()
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
                NotificationID.reminder(habitId: habitId, dayKey: todayKey),
                NotificationID.missAlert(habitId: habitId, dayKey: todayKey),
                NotificationID.missAlert(habitId: habitId, dayKey: ContinuumDay.key(byAdding: 1, to: todayKey)),
            ])
        }
        return .result()
    }
}

// MARK: - Widget Entry

struct HabitEntry: TimelineEntry {
    let date: Date
    let habits: [HabitData]
}

// MARK: - Widget Timeline Provider

struct HabitProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: Date(), habits: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> Void) {
        completion(HabitEntry(date: Date(), habits: HabitDataManager.shared.loadAllHabitData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) {
        let entry = HabitEntry(date: Date(), habits: HabitDataManager.shared.loadAllHabitData())
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
    var size: CGFloat = 22

    var body: some View {
        Button(intent: ToggleHabitIntent(habitId: habit.id)) {
            // One circle: outlined while open, filled with a check once done
            ZStack {
                if habit.isCompletedToday {
                    Circle().fill(color)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.black)
                } else {
                    Circle().strokeBorder(color.opacity(0.6), lineWidth: 1.5)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(habit.isCompletedToday ? "Done today" : "Mark today done")
    }
}

// MARK: - Small Widget — Single Habit Card

struct SmallWidgetView: View {
    let habit: HabitData?

    private var consistency: ConsistencyTally { habit?.consistency ?? ConsistencyTally() }
    private var color: Color { HabitPalette.color(HabitMath.colorProgress(consistency)) }
    /// Days back to the first one done; squares older than that weren't misses
    private var startIndex: Int? {
        habit?.completedKeys.min().map { ContinuumDay.daysBetween($0, ContinuumDay.todayKey()) }
    }

    private var flags: [Bool] {
        guard let h = habit else { return Array(repeating: false, count: 66) }
        var r = h.historyCompletionFlags(daysBack: 66)
        while r.count < 66 { r.append(false) }
        return Array(r.prefix(66).reversed())
    }

    var body: some View {
        if let habit {
            // Same layout as a medium widget card: name and number, the
            // button top right, the grid filling the rest
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(habit.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if let percent = consistency.percent {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text("\(percent)%")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(color)
                                if let trend = habit.consistencyTrend, trend != 0 {
                                    TrendLabel(trend: trend, color: color, size: 9)
                                }
                            }
                        } else {
                            Text("NEW").readoutLabel()
                        }
                    }
                    Spacer(minLength: 0)
                    CompleteButton(habit: habit, color: color)
                }

                Spacer(minLength: 0)

                MiniGrid(flags: flags, color: color, columns: 11, rows: 6, dotSpacing: 2, startIndex: startIndex)
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
                .foregroundStyle(HabitPalette.accent.opacity(0.4))
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
    /// Every habit pooled, the same way as the app's header.
    private var overall: ConsistencyTally {
        habits.reduce(ConsistencyTally()) { $0 + $1.consistency }
    }

    var body: some View {
        if habits.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(HabitPalette.accent.opacity(0.4))
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(HabitPalette.color(HabitMath.colorProgress(overall, habits: habits.count)))
                        Text("/\(habits.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.25))
                        Text(allDone ? "ALL DONE" : "TODAY")
                            .readoutLabel()
                            .padding(.leading, 4)
                    }

                    Spacer()

                    // Consistency across every habit, as the app's header shows it
                    if let percent = overall.percent {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(percent)%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(HabitPalette.color(HabitMath.colorProgress(overall, habits: habits.count)))
                            Text("CONSISTENT")
                                .readoutLabel()
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
                .padding(.bottom, 4)

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
}

// MARK: - Medium Widget Habit Card

private struct MediumHabitCard: View {
    let habit: HabitData

    private var consistency: ConsistencyTally { habit.consistency }
    private var color: Color { HabitPalette.color(HabitMath.colorProgress(consistency)) }
    private var startIndex: Int? {
        habit.completedKeys.min().map { ContinuumDay.daysBetween($0, ContinuumDay.todayKey()) }
    }

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
                    // Mono runs wide in a third of a medium widget
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CompleteButton(habit: habit, color: color, size: 16)
            }

            // Always rendered: an if here makes one card's grid sit higher
            // than its neighbour's, which is what made the widget look broken.
            Text(consistency.percent.map { "\($0)%" } ?? "new")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(consistency.percent != nil ? color.opacity(0.8) : .white.opacity(0.25))

            Spacer(minLength: 2)

            // Mini grid — compact version
            MiniGrid(flags: flags, color: color, columns: 11, rows: 6, dotSpacing: 1.5, startIndex: startIndex)
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
                    .trim(from: 0, to: max(0.04, habit.consistency.fraction))
                    .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)

                let percent = habit.consistency.percent.map(String.init) ?? "–"
                if habit.isCompletedToday {
                    VStack(spacing: 0) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                        Text("\(percent)%")
                            .font(.system(size: 11, weight: .semibold))
                    }
                } else {
                    VStack(spacing: 0) {
                        Text(percent)
                            .font(.system(size: 15, weight: .semibold))
                        Text("%")
                            .font(.system(size: 8, weight: .semibold))
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
                        .minimumScaleFactor(0.8)
                }
                HStack(spacing: 4) {
                    Text(first.consistency.percent.map { "\($0)% consistent" } ?? "new")
                    if let trend = first.consistencyTrend, trend != 0 {
                        TrendLabel(trend: trend, color: .primary, size: 11)
                    }
                }
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
    var startIndex: Int? = nil

    var body: some View {
        // Flexible columns stretch to the card's real width. The old
        // GeometryReader + fixed aspectRatio shrank the grid to a
        // height-constrained box and stranded it against the left edge.
        // The minimum matters: .flexible() defaults to 10pt a column, so 11
        // columns couldn't go under ~125pt and the medium widget's three
        // cards overflowed its sides.
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 1), spacing: dotSpacing), count: columns),
            spacing: dotSpacing
        ) {
            ForEach(0..<(rows * columns), id: \.self) { idx in
                let filled = idx < flags.count && flags[idx]
                let isToday = idx == 0
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(HabitPalette.cell(filled: filled, isToday: isToday, notStarted: startIndex.map { idx > $0 } ?? true, color: color))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

// MARK: - Widget Configuration

struct ContinuumWidget: Widget {
    let kind: String = "continuumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
            ContinuumWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("continuum")
        .description("Your consistency at a glance. On the home screen, a button marks today done.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct ContinuumWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: HabitEntry

    var body: some View {
        content.fontDesign(.monospaced)
    }

    @ViewBuilder
    private var content: some View {
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
        ]
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
        ]
    )
}

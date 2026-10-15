import SwiftUI
import Charts

/// Every habit pooled, over time: the home header's consistency as it stood
/// each day, with the 80% strong line. Opened by tapping the header.
struct OverallStatsView: View {
    let habits: [Habit]
    @Environment(\.dismiss) private var dismiss

    enum Range: Int, CaseIterable, Identifiable {
        case month = 30, quarter = 90, year = 365
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .month: return "1M"
            case .quarter: return "3M"
            case .year: return "1Y"
            }
        }
    }

    @State private var range: Range = .quarter

    private struct Point: Identifiable {
        let date: Date
        let percent: Int
        var id: Date { date }
    }

    /// Days with a number; the stretch before any habit started is left off.
    private var points: [Point] {
        let today = ContinuumDay.todayKey()
        return HabitMath.pooledHistory(habits.map(\.completedDayKeys), todayKey: today, days: range.rawValue)
            .compactMap { day in
                day.tally.percent.map { Point(date: ContinuumDay.storageDate(for: day.dayKey), percent: $0) }
            }
    }

    private var now: ConsistencyTally {
        habits.reduce(ConsistencyTally()) { $0 + $1.consistency }
    }

    private var accent: Color {
        HabitPalette.color(HabitMath.colorProgress(now, habits: habits.count))
    }

    var body: some View {
        let points = self.points
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero(points)
                    chart(points)
                    habitList
                    Text("Each day's number is what the home screen showed that day: every habit pooled over its last 4 weeks. 80% is strong.")
                        .font(.system(size: 10).monospaced())
                        .foregroundStyle(.white.opacity(0.25))
                        .lineSpacing(3)
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ALL HABITS")
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") { dismiss() }
                        .font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private func hero(_ points: [Point]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CONSISTENT · LAST 4 WEEKS")
                .readoutLabel(size: 10)
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(now.percent.map { "\($0)%" } ?? "–")
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.45), radius: 8)
                if let high = points.map(\.percent).max(), let low = points.map(\.percent).min() {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HIGH \(high)%")
                        Text("LOW \(low)%")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }

    private func chart(_ points: [Point]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Range", selection: $range) {
                ForEach(Range.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            if points.count < 2 {
                Text("Mark a few days and the line starts here.")
                    .font(.system(size: 11, weight: .medium).monospaced())
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart {
                    ForEach(points) { point in
                        AreaMark(x: .value("Day", point.date), y: .value("Consistency", point.percent))
                            .foregroundStyle(LinearGradient(colors: [accent.opacity(0.25), accent.opacity(0)],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", point.date), y: .value("Consistency", point.percent))
                            .foregroundStyle(accent)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    RuleMark(y: .value("Strong", HabitMath.strongPercent))
                        .foregroundStyle(.white.opacity(0.25))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .bottom, alignment: .trailing) {
                            Text("STRONG")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.06))
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: range == .year ? .dateTime.month(.abbreviated) : .dateTime.month(.abbreviated).day())
                    }
                }
                .font(.system(size: 9).monospaced())
                .frame(height: 200)
                .accessibilityLabel("Consistency across all habits, last \(range.rawValue) days")
            }
        }
    }

    private var habitList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BY HABIT")
                .readoutLabel(size: 10)
            ForEach(HabitSort.mostConsistent.sorted(habits)) { habit in
                HStack {
                    Text(habit.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    if habit.isStrong {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(HabitPalette.gold)
                    }
                    Spacer()
                    Text(habit.consistency.percent.map { "\($0)%" } ?? "new")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(HabitPalette.color(HabitMath.colorProgress(habit.consistency)))
                }
            }
        }
    }
}

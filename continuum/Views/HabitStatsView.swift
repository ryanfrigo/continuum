import SwiftUI
import SwiftData

/// Full-year stats for a single habit: GitHub-style heatmap of the last 365
/// days plus headline numbers. The screen long-term users screenshot.
struct HabitStatsView: View {
    @Bindable var habit: Habit
    @Environment(\.dismiss) private var dismiss

    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false
    @State private var showContent = false

    // MARK: - Derived data

    private var completedKeys: Set<Int> { habit.completedDayKeys }
    private var frozenKeys: Set<Int> { habit.frozenDayKeys }
    private var health: Double { habit.habitHealth() }

    private var themeColor: Color {
        let hueOrange: Double = 30.0 / 360.0
        let hueGreen: Double = 140.0 / 360.0
        let hueCyan: Double = 175.0 / 360.0
        let clamped = max(0, min(1, health))
        if clamped <= 0.5 {
            let t = clamped / 0.5
            return Color(hue: hueOrange + (hueGreen - hueOrange) * t, saturation: 0.85, brightness: 0.95)
        } else {
            let t = (clamped - 0.5) / 0.5
            return Color(hue: hueGreen + (hueCyan - hueGreen) * t, saturation: 0.75, brightness: 0.9)
        }
    }

    private static let startedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    statTiles
                    heatmapSection
                    footerSection
                }
                .padding(20)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("STATS")
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(2)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("DONE") { dismiss() }
                        .font(.caption.monospaced())
                        .foregroundStyle(.orange)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        shareImage = ShareCardGenerator.generateImage(habit: habit, format: .story)
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showContent = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(habit.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if habit.isGraduated {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                        Text("FORMED")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(Color(hue: 0.12, saturation: 0.8, brightness: 0.95))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(hue: 0.12, saturation: 0.8, brightness: 0.95).opacity(0.12)))
                }
            }

            Text("STARTED \(Self.startedFormatter.string(from: habit.createdAt).uppercased())")
                .font(.system(size: 10, weight: .medium).monospaced())
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1)
        }
    }

    // MARK: - Stat tiles

    private var statTiles: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        let perfectWeeks = weekColumns.filter(\.isPerfect).count
        let current = habit.currentStreak()
        let longest = habit.longestStreak()
        return LazyVGrid(columns: columns, spacing: 10) {
            statTile(value: "\(current)", unit: current == 1 ? "day" : "days", label: "CURRENT STREAK", color: themeColor)
            statTile(value: "\(longest)", unit: longest == 1 ? "day" : "days", label: "LONGEST STREAK", color: themeColor)
            statTile(value: "\(completedKeys.count)", unit: "total", label: "DAYS COMPLETED", color: themeColor)
            statTile(value: "\(Int(health * 100))", unit: "%", label: "HEALTH · 66 DAYS", color: themeColor)
            statTile(value: "\(perfectWeeks)", unit: perfectWeeks == 1 ? "week" : "weeks", label: "PERFECT WEEKS", color: goldColor)
        }
    }

    private func statTile(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold).monospaced())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.10, green: 0.11, blue: 0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Year heatmap

    private struct WeekColumn: Identifiable {
        let id: Int          // index
        let dayKeys: [Int?]  // 7 entries, nil = outside the 365-day window
        let monthLabel: String?
        let isPerfect: Bool  // all 7 days in window AND completed
    }

    private var weekColumns: [WeekColumn] {
        let todayKey = ContinuumDay.todayKey()
        let windowStart = ContinuumDay.key(byAdding: -364, to: todayKey)
        let completed = completedKeys

        // Snap back to the start of the week containing windowStart
        let firstWeekday = ContinuumDay.calendar.firstWeekday // 1 = Sunday
        let startWeekday = ContinuumDay.weekday(of: windowStart)
        let lead = (startWeekday - firstWeekday + 7) % 7
        let gridStart = ContinuumDay.key(byAdding: -lead, to: windowStart)

        let monthSymbols = ContinuumDay.utcCalendar.shortMonthSymbols

        var columns: [WeekColumn] = []
        var cursor = gridStart
        var index = 0
        while ContinuumDay.daysBetween(cursor, todayKey) >= 0 {
            var days: [Int?] = []
            var label: String? = nil
            for _ in 0..<7 {
                let inWindow = ContinuumDay.daysBetween(windowStart, cursor) >= 0
                    && ContinuumDay.daysBetween(cursor, todayKey) >= 0
                days.append(inWindow ? cursor : nil)
                if inWindow && cursor % 100 == 1 {
                    // Column containing the 1st of a month gets its label
                    let monthIndex = (cursor / 100) % 100 - 1
                    if monthIndex >= 0 && monthIndex < monthSymbols.count {
                        label = monthSymbols[monthIndex].uppercased()
                    }
                }
                cursor = ContinuumDay.key(byAdding: 1, to: cursor)
            }
            let isPerfect = days.allSatisfy { $0 != nil && completed.contains($0!) }
            columns.append(WeekColumn(id: index, dayKeys: days, monthLabel: label, isPerfect: isPerfect))
            index += 1
        }
        return columns
    }

    private var goldColor: Color {
        Color(hue: 0.12, saturation: 0.8, brightness: 0.95)
    }

    private var heatmapSection: some View {
        let columns = weekColumns
        let todayKey = ContinuumDay.todayKey()
        let cell: CGFloat = 9
        let spacing: CGFloat = 2.5

        return VStack(alignment: .leading, spacing: 10) {
            Text("LAST 365 DAYS")
                .font(.system(size: 10, weight: .semibold).monospaced())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    // Month labels
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(columns) { col in
                            Text(col.monthLabel ?? " ")
                                .font(.system(size: 7, weight: .semibold).monospaced())
                                .foregroundStyle(.white.opacity(0.35))
                                .frame(width: cell, alignment: .leading)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .frame(height: 10, alignment: .bottom)
                    .clipped()

                    // Grid
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(columns) { col in
                            VStack(spacing: spacing) {
                                ForEach(0..<7, id: \.self) { row in
                                    heatCell(for: col.dayKeys[row], todayKey: todayKey, size: cell)
                                }
                            }
                        }
                    }

                    // Perfect-week markers — gold underline per flawless column
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(columns) { col in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(col.isPerfect ? goldColor : Color.clear)
                                .frame(width: cell, height: 2)
                                .shadow(color: col.isPerfect ? goldColor.opacity(0.6) : .clear, radius: 2)
                        }
                    }
                    .padding(.top, 1)
                }
                .padding(.vertical, 2)
            }
            .defaultScrollAnchor(.trailing)

            // Legend
            HStack(spacing: 12) {
                legendDot(color: themeColor, label: "done")
                legendDot(color: .cyan.opacity(0.7), label: "freeze")
                legendDot(color: goldColor, label: "perfect week")
                legendDot(color: Color.white.opacity(0.08), label: "missed")
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.10, green: 0.11, blue: 0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(themeColor.opacity(0.22), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func heatCell(for key: Int?, todayKey: Int, size: CGFloat) -> some View {
        if let key {
            let completed = completedKeys.contains(key)
            let frozen = frozenKeys.contains(key)
            let isToday = key == todayKey

            RoundedRectangle(cornerRadius: 2)
                .fill(completed ? themeColor : (frozen ? Color.cyan.opacity(0.55) : Color.white.opacity(0.07)))
                .frame(width: size, height: size)
                .overlay {
                    if isToday && !completed {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(themeColor.opacity(0.6), lineWidth: 1)
                    }
                }
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9, weight: .medium).monospaced())
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if habit.streakFreezeCount > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.cyan.opacity(0.7))
                    Text("\(habit.streakFreezeCount) streak freeze\(habit.streakFreezeCount == 1 ? "" : "s") available")
                        .font(.system(size: 11, weight: .medium).monospaced())
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Text("66 consecutive days forms a habit. Frozen days protect your streak when life happens.")
                .font(.system(size: 10).monospaced())
                .foregroundStyle(.white.opacity(0.25))
                .lineSpacing(3)
        }
        .padding(.top, 4)
    }
}

#Preview {
    HabitStatsView(habit: {
        let h = Habit(name: "Cold Shower")
        h.addRecentDays(40)
        return h
    }())
}

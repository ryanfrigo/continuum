import SwiftUI
import SwiftData

struct HabitHistoryEditView: View {
    @Bindable var habit: Habit
    var onCancel: () -> Void
    var onSave: () -> Void

    @State private var selectedDates: Set<Date> = []
    @State private var isDragging = false
    @State private var dragStartDate: Date? = nil
    @State private var dragMode: Bool = true // true = selecting, false = deselecting
    @State private var showContent = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 50))
                                .foregroundStyle(.orange)
                                .scaleEffect(showContent ? 1 : 0.5)
                                .opacity(showContent ? 1 : 0)

                            Text("EDIT HISTORY")
                                .font(.title3.weight(.bold).monospaced())
                                .foregroundStyle(.white)
                                .tracking(2)
                                .opacity(showContent ? 1 : 0)

                            Text("TAP OR DRAG TO SELECT DAYS")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.gray)
                                .tracking(1)
                                .opacity(showContent ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                        // Calendar grid grouped by month (oldest first, scroll up for past)
                        let groupedDays = groupDaysByMonth()

                        ForEach(groupedDays, id: \.month) { monthData in
                        VStack(alignment: .leading, spacing: 12) {
                            // Month header
                            Text(monthData.monthName)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 4)

                            // Day of week headers
                            HStack(spacing: 0) {
                                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                                    Text(day)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.gray)
                                        .frame(maxWidth: .infinity)
                                }
                            }

                            // Days grid with drag gesture
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                                // Add empty cells for alignment
                                ForEach(0..<monthData.leadingEmptyCells, id: \.self) { _ in
                                    Color.clear
                                        .frame(height: 44)
                                }

                                ForEach(monthData.days, id: \.self) { date in
                                    DayCell(
                                        date: date,
                                        isCompleted: isDateCompleted(date),
                                        isInRange: isInDragRange(date)
                                    )
                                    .id(date)
                                }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        handleDrag(value: value, days: monthData.days)
                                    }
                                    .onEnded { _ in
                                        finishDrag()
                                    }
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .id(monthData.month)
                    }

                    // Anchor for scrolling to bottom
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding()
                .onAppear {
                    // Scroll to bottom (current month) after layout
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") { onCancel() }
                        .font(.caption.monospaced())
                        .foregroundStyle(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("SAVE") { onSave() }
                        .font(.caption.monospaced())
                        .foregroundStyle(.orange)
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            selectedDates = Set(habit.completedDates.map { calendar.startOfDay(for: $0) })
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }

    // MARK: - Month Grouping

    private struct MonthData {
        let month: Date
        let monthName: String
        let days: [Date]
        let leadingEmptyCells: Int
    }

    private func groupDaysByMonth() -> [MonthData] {
        let days = generateLast66Days()
        var grouped: [Date: [Date]] = [:]

        for day in days {
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: day))!
            grouped[monthStart, default: []].append(day)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        // Sorted chronologically - oldest first, current month at bottom
        return grouped.keys.sorted().map { monthStart in
            let monthDays = grouped[monthStart]!.sorted()
            let firstDay = monthDays.first!
            let weekday = calendar.component(.weekday, from: firstDay)
            // Calculate empty cells needed before first day (Sunday = 1)
            let leadingCells = (weekday - 1)

            return MonthData(
                month: monthStart,
                monthName: formatter.string(from: monthStart),
                days: monthDays,
                leadingEmptyCells: leadingCells
            )
        }
    }

    private func generateLast66Days() -> [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<66).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    // MARK: - Selection State

    private func isDateCompleted(_ date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        return selectedDates.contains(dayStart)
    }

    @State private var dragCurrentDate: Date? = nil

    private func isInDragRange(_ date: Date) -> Bool {
        guard isDragging, let start = dragStartDate, let current = dragCurrentDate else {
            return false
        }
        let dayStart = calendar.startOfDay(for: date)
        let minDate = min(start, current)
        let maxDate = max(start, current)
        return dayStart >= minDate && dayStart <= maxDate
    }

    // MARK: - Drag Handling

    private func handleDrag(value: DragGesture.Value, days: [Date]) {
        // Calculate which date is being touched based on position
        if !isDragging {
            isDragging = true
            // Find initial date from tap location
            if let date = findDateAtLocation(value.startLocation, in: days) {
                dragStartDate = calendar.startOfDay(for: date)
                dragMode = !isDateCompleted(date) // If not completed, we're selecting
                dragCurrentDate = dragStartDate

                #if os(iOS)
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                #endif
            }
        }

        // Update current drag position
        if let date = findDateAtLocation(value.location, in: days) {
            let newDate = calendar.startOfDay(for: date)
            if newDate != dragCurrentDate {
                dragCurrentDate = newDate
                #if os(iOS)
                let impact = UIImpactFeedbackGenerator(style: .soft)
                impact.impactOccurred()
                #endif
            }
        }
    }

    private func findDateAtLocation(_ location: CGPoint, in days: [Date]) -> Date? {
        // Approximate cell size based on typical layout
        let cellWidth: CGFloat = (UIScreen.main.bounds.width - 48) / 7
        let cellHeight: CGFloat = 50

        let col = Int(location.x / cellWidth)
        let row = Int(location.y / cellHeight)

        let index = row * 7 + col

        // Account for leading empty cells
        let sortedDays = days.sorted()
        guard let firstDay = sortedDays.first else { return nil }
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingCells = weekday - 1

        let adjustedIndex = index - leadingCells

        if adjustedIndex >= 0 && adjustedIndex < sortedDays.count {
            return sortedDays[adjustedIndex]
        }
        return nil
    }

    private func finishDrag() {
        guard let start = dragStartDate, let end = dragCurrentDate else {
            isDragging = false
            dragStartDate = nil
            dragCurrentDate = nil
            return
        }

        let minDate = min(start, end)
        let maxDate = max(start, end)

        // Get all days in range
        var current = minDate
        while current <= maxDate {
            if dragMode {
                // Selecting
                if !selectedDates.contains(current) {
                    selectedDates.insert(current)
                    habit.completedDates.append(current)
                }
            } else {
                // Deselecting
                if selectedDates.contains(current) {
                    selectedDates.remove(current)
                    habit.completedDates.removeAll { calendar.isDate($0, inSameDayAs: current) }
                }
            }
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        #endif

        isDragging = false
        dragStartDate = nil
        dragCurrentDate = nil
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let isCompleted: Bool
    let isInRange: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            Text(dayOfMonth)
                .font(.caption.weight(.medium))
                .foregroundStyle(isToday ? .orange : .white.opacity(0.8))

            Circle()
                .fill(fillColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(isInRange ? Color.orange : Color.clear, lineWidth: 2)
                )
        }
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    private var fillColor: Color {
        if isCompleted || isInRange {
            return Color.orange
        }
        return Color.gray.opacity(0.3)
    }

    private var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
}

#Preview {
    HabitHistoryEditView(
        habit: Habit(name: "Test"),
        onCancel: {},
        onSave: {}
    )
}

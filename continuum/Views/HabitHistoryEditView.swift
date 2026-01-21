import SwiftUI
import SwiftData

struct HabitHistoryEditView: View {
    @Bindable var habit: Habit
    var onCancel: () -> Void
    var onSave: () -> Void

    @State private var selectedDates: Set<Date> = []
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Edit Completion History")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Tap dates to toggle completion status for the last 66 days.")
                        .font(.caption)
                        .foregroundStyle(.gray)

                    // Show last 66 days in a grid
                    let days = generateLast66Days()

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                        ForEach(days, id: \.self) { date in
                            DayCell(
                                date: date,
                                isCompleted: isDateCompleted(date),
                                onTap: { toggleDate(date) }
                            )
                        }
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Edit History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            selectedDates = Set(habit.completedDates.map { calendar.startOfDay(for: $0) })
        }
    }

    private func generateLast66Days() -> [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<66).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
    }

    private func isDateCompleted(_ date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        return selectedDates.contains(dayStart)
    }

    private func toggleDate(_ date: Date) {
        let dayStart = calendar.startOfDay(for: date)
        if selectedDates.contains(dayStart) {
            selectedDates.remove(dayStart)
            habit.completedDates.removeAll { calendar.isDate($0, inSameDayAs: date) }
        } else {
            selectedDates.insert(dayStart)
            habit.completedDates.append(dayStart)
        }
    }
}

private struct DayCell: View {
    let date: Date
    let isCompleted: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            Text(dayOfMonth)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isToday ? .orange : .white)

            Circle()
                .fill(isCompleted ? Color.orange : Color.gray.opacity(0.3))
                .frame(width: 28, height: 28)
        }
        .frame(height: 50)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
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

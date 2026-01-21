import SwiftUI
import SwiftData

struct HabitCardView: View {
    @Bindable var habit: Habit
    var refreshTrigger: Bool = false
    var onAction: ((HabitAction) -> Void)? = nil
    var onCompletion: ((Bool) -> Void)? = nil  // Called when habit is toggled, passes whether it was completed

    // Visual constants
    private let cornerRadius: CGFloat = 14
    private let borderWidth: CGFloat = 1
    private let dotSpacing: CGFloat = 4
    // Exactly 66 days → 6 rows × 11 columns
    private let columnsCount: Int = 11
    private let habitFormationDays: Int = 66

    @State private var showingSetStreak = false
    @State private var selectedStreak: Int = 0
    @State private var showingRename = false
    @State private var newHabitName: String = ""
    @State private var showingDeleteConfirmation = false
    
    // Animation states
    @State private var wasCompletedToday = false
    @State private var lastRefreshDate = Date()
    @State private var checkmarkScale: CGFloat = 0
    @State private var showCheckmark = false
    @State private var cardScale: CGFloat = 1.0
    @State private var gridSquareAnimationProgress: [Bool] = Array(repeating: false, count: 66)

    private func shouldShowStreak() -> Bool {
        // Don't show "0 DAY STREAK" until the day has fully passed without completion
        let currentStreak = habit.currentStreak()
        let isCompletedToday = habit.isCompletedToday
        
        // If streak is 0 and not completed today, don't show it
        if currentStreak == 0 && !isCompletedToday {
            return false
        }
        
        return true
    }
    
    private func getStreakText() -> String {
        let hasAnyCompletion = !habit.completedDates.isEmpty

        // If there's any completion history, always show the streak count
        if hasAnyCompletion {
            let streak = getDisplayStreak()
            return "\(streak) DAY STREAK"
        } else {
            // Only show "Start today" if there's no completion history at all
            return "Start today"
        }
    }

    private func getStreakStartText() -> String? {
        guard let startDate = habit.streakStartDate() else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Since \(formatter.string(from: startDate))"
    }

    private func getHealthText() -> String {
        let health = habit.habitHealth()
        let percentage = Int(health * 100)
        return "\(percentage)%"
    }
    
    private func getDisplayStreak() -> Int {
        let isCompletedToday = habit.isCompletedToday
        
        if isCompletedToday {
            // If today is completed, show current streak including today
            return habit.currentStreak()
        } else {
            // If today is not completed, show streak up to yesterday
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            return habit.currentStreak(asOf: yesterday)
        }
    }

    /// Returns color based on habit health (% of last 66 days completed)
    /// 0% = Orange, 100% = Deep Green/Blue
    private func healthColor(for health: Double) -> Color {
        // Palette tuned to harmonize with iOS orange
        // Phase 1 (0-66%): Orange (38°) → Balanced Green (130°)
        // Phase 2 (66-100%): Balanced Green (130°) → Deep Teal/Blue (180°)
        let hueOrange: Double = 38.0 / 360.0
        let hueGreen: Double = 130.0 / 360.0
        let hueTeal: Double = 180.0 / 360.0

        // Keep saturation close to orange; adjust brightness
        let satStart: Double = 0.94
        let briStart: Double = 0.98
        let satGreen: Double = 0.85
        let briGreen: Double = 0.95
        let satTeal: Double = 0.80
        let briTeal: Double = 0.85

        let clampedHealth = max(0, min(1, health))

        if clampedHealth <= 0.66 {
            // Phase 1: Orange to Green (0% to 66%)
            let t = clampedHealth / 0.66
            let hue = hueOrange + (hueGreen - hueOrange) * t
            let sat = satStart + (satGreen - satStart) * t
            let bri = briStart + (briGreen - briStart) * t
            return Color(hue: hue, saturation: sat, brightness: bri)
        } else {
            // Phase 2: Green to Teal (66% to 100%)
            let t = (clampedHealth - 0.66) / 0.34
            let hue = hueGreen + (hueTeal - hueGreen) * t
            let sat = satGreen + (satTeal - satGreen) * t
            let bri = briGreen + (briTeal - briGreen) * t
            return Color(hue: hue, saturation: sat, brightness: bri)
        }
    }
    
    private func triggerCompletionAnimation() {
        wasCompletedToday = habit.isCompletedToday

        // Show checkmark overlay
        showCheckmark = true
        checkmarkScale = 0

        // Animate card press
        withAnimation(.easeInOut(duration: 0.1)) {
            cardScale = 0.95
        }

        // Bounce back
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) {
            cardScale = 1.0
        }

        // Animate checkmark appearance with spring
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            checkmarkScale = 1.0
        }

        // Hide checkmark after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                checkmarkScale = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showCheckmark = false
            }
        }
    }

    private var borderColor: Color {
        healthColor(for: habit.habitHealth())
    }

    private var paddedFlags: [Bool] {
        var result = habit.historyCompletionFlags(daysBack: habitFormationDays)
        while result.count < habitFormationDays {
            result.append(false)
        }
        return Array(result.prefix(habitFormationDays))
    }

    @ViewBuilder
    private func headerView() -> some View {
        HStack(alignment: .top) {
            Text(habit.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text(getHealthText())
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(borderColor)
        }
    }

    @ViewBuilder
    private func streakInfoRow() -> some View {
        HStack(spacing: 8) {
            Text(getStreakText())
                .font(.caption.monospaced())
                .foregroundStyle(.gray)
                .animation(nil, value: getStreakText())
            if let startText = getStreakStartText(), habit.currentStreak() > 0 {
                Text("·")
                    .foregroundStyle(.gray.opacity(0.5))
                Text(startText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.gray.opacity(0.7))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func historyGrid() -> some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let availableWidth = totalWidth - CGFloat(columnsCount - 1) * dotSpacing
            let dotSize = floor(availableWidth / CGFloat(columnsCount))
            let columns = Array(repeating: GridItem(.fixed(dotSize), spacing: dotSpacing), count: columnsCount)
            let rowsCount = 6
            let gridHeight = dotSize * CGFloat(rowsCount) + dotSpacing * CGFloat(rowsCount - 1)

            LazyVGrid(columns: columns, alignment: .leading, spacing: dotSpacing) {
                ForEach(0..<habitFormationDays, id: \.self) { idx in
                    let filled = paddedFlags[idx]
                    Rectangle()
                        .fill(filled ? borderColor : Color.gray.opacity(0.3))
                        .frame(width: dotSize, height: dotSize)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                        .animation(nil, value: filled)
                        .animation(nil, value: borderColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: gridHeight)
        }
        .frame(height: 80)
    }

    @ViewBuilder
    private func checkmarkOverlay() -> some View {
        if showCheckmark {
            ZStack {
                Circle()
                    .fill(borderColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(borderColor)
            }
            .scaleEffect(checkmarkScale)
        }
    }

    var body: some View {
        let _ = lastRefreshDate // Force refresh when this changes

        ZStack {
            VStack(alignment: .leading, spacing: 6) {
                headerView()
                streakInfoRow()
                historyGrid()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
                    .animation(nil, value: borderColor)
            )
            .clipped()
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(cardScale)

            checkmarkOverlay()
        }
        .animation(nil, value: habit.completedDates)
        .onAppear {
            // Ensure the view shows current day/streak status immediately when it appears
            lastRefreshDate = Date()
        }
        .onChange(of: refreshTrigger) {
            // Force UI refresh when app becomes active to show current day/streak
            // This ensures the display updates without requiring user interaction
            lastRefreshDate = Date()
        }
        .onTapGesture {
            let wasCompleted = habit.isCompletedToday
            habit.toggleCompletion()

            // Sync widget data after completion change
            let habitData = HabitData(from: habit)
            HabitDataManager.shared.saveHabitData(habitData)
            HabitDataManager.shared.updateWidgetTimeline()

            // Add haptic feedback
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            #endif

            // Only trigger completion animation if we just completed the habit
            if !wasCompleted && habit.isCompletedToday {
                // Add stronger haptic feedback for completion
                #if os(iOS)
                let completionFeedback = UIImpactFeedbackGenerator(style: .medium)
                completionFeedback.impactOccurred()
                #endif

                triggerCompletionAnimation()
            }

            // Notify parent about the completion change
            onCompletion?(habit.isCompletedToday)
        }
        .contextMenu {
            Button("Reset", role: .destructive) { onAction?(.reset) }
            Divider()
            Button("Change Name") {
                newHabitName = habit.name
                showingRename = true
            }
            Button("Change Streak") {
                selectedStreak = habit.currentStreak()
                showingSetStreak = true
            }
            Divider()
            Button("Delete", role: .destructive) { 
                showingDeleteConfirmation = true
            }
        }
        .sheet(isPresented: $showingSetStreak) {
            HabitHistoryEditView(habit: habit) {
                showingSetStreak = false
            } onSave: {
                // Sync widget data after history changes
                let habitData = HabitData(from: habit)
                HabitDataManager.shared.saveHabitData(habitData)
                HabitDataManager.shared.updateWidgetTimeline()
                showingSetStreak = false
            }
        }
        .sheet(isPresented: $showingRename) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Change Habit Name")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    TextField("Habit name", text: $newHabitName)
                        .textFieldStyle(.roundedBorder)
                        .tint(.orange)
                        .onSubmit {
                            if !newHabitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onAction?(.rename(newHabitName.trimmingCharacters(in: .whitespacesAndNewlines)))
                                showingRename = false
                            }
                        }

                    Spacer()
                }
                .padding()
                .background(Color.black.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingRename = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if !newHabitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onAction?(.rename(newHabitName.trimmingCharacters(in: .whitespacesAndNewlines)))
                                showingRename = false
                            }
                        }
                        .disabled(newHabitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .confirmationDialog("Delete Habit", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onAction?(.delete)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(habit.name)\"? This action cannot be undone.")
        }
        .accessibilityAddTraits(.isButton)
    }
}

enum HabitAction {
    case reset
    case setStreak(Int)
    case rename(String)
    case delete
}

#Preview {
    let habit = Habit(name: "Read")
    HabitCardView(habit: habit, refreshTrigger: false)
        .padding()
        .background(Color.black)
}







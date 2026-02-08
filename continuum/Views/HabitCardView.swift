import SwiftUI
import SwiftData

struct HabitCardView: View {
    @Bindable var habit: Habit
    var refreshTrigger: Bool = false
    var onAction: ((HabitAction) -> Void)? = nil
    var onCompletion: ((Bool) -> Void)? = nil

    // Visual constants
    private let cornerRadius: CGFloat = 20
    private let columnsCount: Int = 11
    private let habitFormationDays: Int = 66

    // Sheet states
    @State private var showingSetStreak = false
    @State private var showingRename = false
    @State private var newHabitName: String = ""
    @State private var showingDeleteConfirmation = false

    // Animation states
    @State private var lastRefreshDate = Date()
    @State private var cardScale: CGFloat = 1.0

    // Completion animation states
    @State private var showCompletionEffect = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var centerIconScale: CGFloat = 0
    @State private var centerIconOpacity: Double = 0
    @State private var gridFlashProgress: Double = 0

    // MARK: - Computed Properties

    private var health: Double {
        habit.habitHealth()
    }

    private var healthPercentage: Int {
        Int(health * 100)
    }

    private var displayStreak: Int {
        habit.isCompletedToday ? habit.currentStreak() : habit.currentStreak(asOf: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
    }

    private var themeColor: Color {
        healthColor(for: health)
    }

    private var paddedFlags: [Bool] {
        var result = habit.historyCompletionFlags(daysBack: habitFormationDays)
        while result.count < habitFormationDays { result.append(false) }
        // Reverse so index 0 = today, index 65 = oldest (65 days ago)
        return Array(result.prefix(habitFormationDays).reversed())
    }

    // MARK: - Color System

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

    // MARK: - Body

    var body: some View {
        let _ = lastRefreshDate

        Button(action: handleTap) {
            ZStack {
                // Main card
                cardContent
                    .scaleEffect(cardScale)

                // Completion effects overlay
                if showCompletionEffect {
                    completionEffectsOverlay
                }
            }
        }
        .buttonStyle(InstantButtonStyle())
        .onAppear {
            lastRefreshDate = Date()
        }
        .onChange(of: refreshTrigger) { lastRefreshDate = Date() }
        .contextMenu { contextMenuContent }
        .sheet(isPresented: $showingSetStreak) { historyEditSheet }
        .sheet(isPresented: $showingRename) { renameSheet }
        .confirmationDialog("Delete Habit", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onAction?(.delete) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(habit.name)\"? This action cannot be undone.")
        }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with name and health
            headerSection

            // Streak information
            streakSection

            // 66-day grid
            historyGridSection
        }
        .padding(18)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            // Habit name
            Text(habit.name)
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 4)

            // Health percentage with ring
            ZStack {
                // Mini progress ring
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: health)
                    .stroke(themeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: themeColor.opacity(0.6), radius: 5)

                Text("\(healthPercentage)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor)
            }
        }
    }

    private var streakSection: some View {
        HStack(spacing: 6) {
            // Streak indicator dot - always reserve space
            Circle()
                .fill(themeColor)
                .frame(width: 6, height: 6)
                .shadow(color: themeColor, radius: 3)
                .opacity(displayStreak > 0 ? 1 : 0)

            // Streak text
            if !habit.completedDatesArray.isEmpty {
                Text("\(displayStreak)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                +
                Text(" day streak")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            } else {
                Text("Tap to start")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }

            Spacer()

            // Today indicator - always present to maintain consistent size
            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                Text("TODAY")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
            }
            .foregroundStyle(themeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(themeColor.opacity(0.15))
            )
            .fixedSize()
            .opacity(habit.isCompletedToday ? 1 : 0)
        }
    }

    private var historyGridSection: some View {
        // Grid is 11 columns × 6 rows with 3pt spacing
        // Aspect ratio: (11*d + 10*3) / (6*d + 5*3) ≈ 1.85 for typical dot sizes
        let gridAspectRatio: CGFloat = 1.85
        let flags = paddedFlags // Cache computed property
        let color = themeColor // Cache computed property

        return Color.clear
            .aspectRatio(gridAspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let spacing: CGFloat = 3
                    let availableWidth = geo.size.width
                    let dotSize = floor((availableWidth - CGFloat(columnsCount - 1) * spacing) / CGFloat(columnsCount))
                    let columns = Array(repeating: GridItem(.fixed(dotSize), spacing: spacing), count: columnsCount)

                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(0..<habitFormationDays, id: \.self) { idx in
                            let filled = flags[idx]
                            let isToday = idx == 0

                            RoundedRectangle(cornerRadius: 2)
                                .fill(dotColor(filled: filled, isToday: isToday, healthColor: color))
                                .frame(width: dotSize, height: dotSize)
                                .overlay {
                                    if isToday && !filled {
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(color.opacity(0.5), lineWidth: 1)
                                    }
                                }
                        }
                    }
                    .drawingGroup() // Render as single layer for better performance
                    .brightness(gridFlashProgress * 0.3) // Apply brightness to entire grid, not individual dots
                }
            }
    }

    private func dotColor(filled: Bool, isToday: Bool, healthColor: Color) -> Color {
        if filled {
            return healthColor
        } else if isToday {
            return Color.white.opacity(0.12)
        } else {
            return Color.white.opacity(0.08)
        }
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        ZStack {
            // Dark slate card background (darker than main bg)
            Color(red: 0.10, green: 0.11, blue: 0.13)

            // Subtle border
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    // MARK: - Completion Effects

    private var completionEffectsOverlay: some View {
        GeometryReader { geo in
            ZStack {
                // Single expanding ripple - smooth and elegant, uses habit's color
                Circle()
                    .stroke(
                        themeColor.opacity(0.6),
                        lineWidth: 1
                    )
                    .frame(width: 30, height: 30)
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)

                // Center checkmark icon - uses habit's color
                ZStack {
                    Circle()
                        .fill(themeColor)
                        .frame(width: 32, height: 32)

                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                }
                .scaleEffect(centerIconScale)
                .opacity(centerIconOpacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func handleTap() {
        let wasCompleted = habit.isCompletedToday

        // INSTANT visual feedback - set states synchronously FIRST
        if !wasCompleted {
            // Visual animation state - INSTANT
            showCompletionEffect = true
            rippleScale = 0
            rippleOpacity = 0.7
            centerIconScale = 0
            centerIconOpacity = 0
            gridFlashProgress = 0

            // Start animations immediately
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cardScale = 0.97
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                cardScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.15)) {
                gridFlashProgress = 1.0
            }
            withAnimation(.easeOut(duration: 0.5)) {
                gridFlashProgress = 0
            }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                centerIconScale = 1.0
                centerIconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.7)) {
                rippleScale = 10.0
                rippleOpacity = 0
            }
            withAnimation(.easeOut(duration: 0.2).delay(0.4)) {
                centerIconScale = 1.15
                centerIconOpacity = 0
            }

            // Sound/haptic feedback - can be slightly delayed, non-blocking
            Task {
                SoundManager.shared.playCompletionBeep()
                SoundManager.shared.triggerCompletionHaptic()
            }

            // Cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showCompletionEffect = false
            }
        } else {
            SoundManager.shared.triggerSelectionHaptic()
        }

        // Update data asynchronously
        habit.toggleCompletion()

        Task.detached(priority: .background) {
            let habitData = HabitData(from: habit)
            HabitDataManager.shared.saveHabitData(habitData)
            HabitDataManager.shared.updateWidgetTimeline()
        }

        onCompletion?(habit.isCompletedToday)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Reset Progress", role: .destructive) { onAction?(.reset) }
        Divider()
        Button("Edit Name") {
            newHabitName = habit.name
            showingRename = true
        }
        Button("Edit History") {
            showingSetStreak = true
        }
        Divider()
        Button("Delete Habit", role: .destructive) {
            showingDeleteConfirmation = true
        }
    }

    // MARK: - Sheets

    private var historyEditSheet: some View {
        HabitHistoryEditView(habit: habit) {
            showingSetStreak = false
        } onSave: {
            let habitData = HabitData(from: habit)
            HabitDataManager.shared.saveHabitData(habitData)
            HabitDataManager.shared.updateWidgetTimeline()
            showingSetStreak = false
        }
    }

    private var renameSheet: some View {
        RenameHabitSheet(habitName: $newHabitName) { newName in
            onAction?(.rename(newName))
            showingRename = false
        } onCancel: {
            showingRename = false
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Supporting Types

enum HabitAction {
    case reset
    case setStreak(Int)
    case rename(String)
    case delete
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            HabitCardView(habit: Habit(name: "Exercise"), refreshTrigger: false)
            HabitCardView(habit: Habit(name: "Meditate"), refreshTrigger: false)
        }
        .padding()
    }
}

// MARK: - Instant Button Style
struct InstantButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
    }
}

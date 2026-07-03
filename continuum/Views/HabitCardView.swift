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

    // Completion progress states
    @State private var isAnimatingCompletion = false
    @State private var completionProgress: CGFloat = 0

    // Hint / undo states
    @State private var showHoldHint = false
    @State private var showUndoConfirm = false

    // Reset confirmation
    @State private var showingResetConfirmation = false

    // Completion animation states
    @State private var showCompletionEffect = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var centerIconScale: CGFloat = 0
    @State private var centerIconOpacity: Double = 0
    @State private var gridFlashProgress: Double = 0

    // Variable reward: ~1 in 15 completions goes golden
    @State private var isRareCompletion = false
    private let goldColor = Color(hue: 0.12, saturation: 0.8, brightness: 0.95)

    private var effectColor: Color {
        isRareCompletion ? goldColor : themeColor
    }

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

    /// How long the user must hold the card to complete it. The fill bar
    /// tracks the press in real time; releasing early cancels.
    private let holdToCompleteDuration: Double = 0.9

    var body: some View {
        let _ = lastRefreshDate

        ZStack {
            // Main card
            cardContent
                .scaleEffect(cardScale)
                .overlay {
                    // Completion progress bar overlay
                    if isAnimatingCompletion {
                        completionProgressOverlay
                    }
                }

            // Completion effects overlay
            if showCompletionEffect {
                completionEffectsOverlay
            }

            // Hold hint overlay
            if showHoldHint {
                holdHintOverlay
            }

            // Undo confirmation overlay
            if showUndoConfirm {
                undoConfirmOverlay
            }
        }
        // Single tap — undo if completed, hint if not
        .onTapGesture {
            if habit.isCompletedToday {
                SoundManager.shared.triggerSelectionHaptic()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showUndoConfirm = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showUndoConfirm = false
                    }
                }
            } else if !isAnimatingCompletion && !showHoldHint {
                SoundManager.shared.triggerSelectionHaptic()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showHoldHint = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showHoldHint = false
                    }
                }
            }
        }
        // Hold to complete — the fill bar tracks the press; release early to cancel
        .onLongPressGesture(minimumDuration: holdToCompleteDuration, maximumDistance: 40) {
            if isAnimatingCompletion {
                finishCompletion()
            }
        } onPressingChanged: { pressing in
            if pressing {
                if !habit.isCompletedToday && !isAnimatingCompletion {
                    startCompletion()
                }
            } else if isAnimatingCompletion {
                cancelCompletion()
            }
        }
        .onAppear {
            lastRefreshDate = Date()
        }
        .onChange(of: refreshTrigger) { lastRefreshDate = Date() }
        .sheet(isPresented: $showingSetStreak) { historyEditSheet }
        .sheet(isPresented: $showingRename) { renameSheet }
        .confirmationDialog("Delete Habit", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onAction?(.delete) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(habit.name)\"? This action cannot be undone.")
        }
        .confirmationDialog("Reset Progress", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { onAction?(.reset) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Erase all history for \"\(habit.name)\"? This cannot be undone.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: habit.isCompletedToday ? "Undo today's completion" : "Complete today") {
            if habit.isCompletedToday {
                habit.toggleCompletion()
                let habitData = HabitData(from: habit)
                Task.detached(priority: .background) {
                    HabitDataManager.shared.saveHabitData(habitData)
                    HabitDataManager.shared.updateWidgetTimeline()
                }
                onCompletion?(false)
            } else if !isAnimatingCompletion {
                finishCompletion()
            }
        }
    }

    private var accessibilitySummary: String {
        var parts = [habit.name]
        if displayStreak > 0 { parts.append("\(displayStreak) day streak") }
        parts.append(habit.isCompletedToday ? "completed today" : "not completed today")
        if habit.isGraduated { parts.append("habit formed") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with name and health
            headerSection

            // Streak information
            streakSection

            // 66-day grid — hero visual, gets remaining space
            historyGridSection
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 6) {
            // Habit name — gets all remaining space
            Text(habit.name)
                .font(.system(size: 15, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Health ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2.5)
                    .frame(width: 32, height: 32)

                Circle()
                    .trim(from: 0, to: health)
                    .stroke(themeColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: themeColor.opacity(0.5), radius: 4)

                Text("\(healthPercentage)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor)
            }

            // Options menu (was the long-press context menu — long press
            // now completes the habit)
            Menu {
                contextMenuContent
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(habit.name)")
        }
    }

    private var streakSection: some View {
        HStack(spacing: 4) {
            if !habit.completedDatesArray.isEmpty {
                Circle()
                    .fill(themeColor)
                    .frame(width: 5, height: 5)
                    .shadow(color: themeColor, radius: 2)
                    .opacity(displayStreak > 0 ? 1 : 0)

                Text("\(displayStreak)d")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if habit.isCompletedToday {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(themeColor)
                }

                if habit.isGraduated {
                    Image(systemName: "star.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(Color(hue: 0.12, saturation: 0.8, brightness: 0.95))
                }
            } else {
                Text("Hold to start")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            Spacer()

            if habit.streakFreezeCount > 0 && !habit.isCompletedToday {
                HStack(spacing: 2) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 6, weight: .bold))
                    Text("\(habit.streakFreezeCount)")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.cyan.opacity(0.7))
            }
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

            // 1px border in the habit's progress color — brighter once
            // today is complete, so the whole grid glows up as you go
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(themeColor.opacity(habit.isCompletedToday ? 0.42 : 0.16), lineWidth: 1)
        }
    }

    // MARK: - Completion Progress Overlay

    private var completionProgressOverlay: some View {
        VStack {
            Spacer()
            // Bottom progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(themeColor)
                        .frame(width: geo.size.width * completionProgress, height: 3)
                        .shadow(color: themeColor.opacity(0.6), radius: 4)
                }
            }
            .frame(height: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
    }

    // MARK: - Completion Effects

    private var completionEffectsOverlay: some View {
        ZStack {
            // Single clean expanding ripple
            Circle()
                .stroke(effectColor.opacity(0.5), lineWidth: 2)
                .frame(width: 30, height: 30)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)

            // Second ripple only on rare (golden) completions
            if isRareCompletion {
                Circle()
                    .stroke(effectColor.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 30, height: 30)
                    .scaleEffect(rippleScale * 0.7)
                    .opacity(rippleOpacity)
            }

            // Center icon — sparkles when golden
            ZStack {
                Circle()
                    .fill(effectColor)
                    .frame(width: 36, height: 36)
                    .shadow(color: effectColor.opacity(isRareCompletion ? 0.8 : 0.5), radius: isRareCompletion ? 16 : 10)

                Image(systemName: isRareCompletion ? "sparkles" : "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
            }
            .scaleEffect(centerIconScale)
            .opacity(centerIconOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Hold Hint Overlay

    private var holdHintOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Hold to complete")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(themeColor.opacity(0.5))
            )
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Undo Confirmation Overlay

    private var undoConfirmOverlay: some View {
        VStack {
            Spacer()
            Button {
                // Actually undo
                SoundManager.shared.triggerSelectionHaptic()
                habit.toggleCompletion()
                let habitData = HabitData(from: habit)
                Task.detached(priority: .background) {
                    HabitDataManager.shared.saveHabitData(habitData)
                    HabitDataManager.shared.updateWidgetTimeline()
                }
                onCompletion?(false)
                withAnimation(.easeOut(duration: 0.2)) {
                    showUndoConfirm = false
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .bold))
                    Text("Tap to Undo")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.6))
                )
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Hold-to-Complete

    private func startCompletion() {
        isAnimatingCompletion = true
        completionProgress = 0

        SoundManager.shared.triggerSelectionHaptic()

        // Gentle card press
        withAnimation(.easeOut(duration: 0.2)) {
            cardScale = 0.97
        }

        // Fill tracks the hold; the gesture's perform fires at full duration
        withAnimation(.linear(duration: holdToCompleteDuration)) {
            completionProgress = 1
        }
    }

    /// Finger lifted before the hold completed — settle back to rest.
    private func cancelCompletion() {
        isAnimatingCompletion = false
        completionProgress = 0
        withAnimation(.easeOut(duration: 0.2)) {
            cardScale = 1.0
        }
    }

    private func finishCompletion() {
        isAnimatingCompletion = false
        completionProgress = 0

        // Variable reward: occasionally the completion goes golden
        isRareCompletion = Int.random(in: 0..<15) == 0

        // Completion effects
        showCompletionEffect = true
        rippleScale = 0
        rippleOpacity = isRareCompletion ? 0.8 : 0.6
        centerIconScale = 0
        centerIconOpacity = 0

        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            cardScale = isRareCompletion ? 1.08 : 1.05
            centerIconScale = 1.0
            centerIconOpacity = 1.0
            gridFlashProgress = 1.0
            rippleScale = isRareCompletion ? 11.0 : 8.0
        }

        if isRareCompletion {
            SoundManager.shared.playRareCompletionSound()
            SoundManager.shared.triggerRareHaptic()
        } else {
            SoundManager.shared.playCompletionBeep()
            SoundManager.shared.triggerCompletionHaptic()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                cardScale = 1.0
                gridFlashProgress = 0
                rippleOpacity = 0
                centerIconOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showCompletionEffect = false
        }

        // Update data
        habit.toggleCompletion()

        let habitData = HabitData(from: habit)
        Task.detached(priority: .background) {
            HabitDataManager.shared.saveHabitData(habitData)
            HabitDataManager.shared.updateWidgetTimeline()
        }

        onCompletion?(habit.isCompletedToday)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            onAction?(.stats)
        } label: {
            Label("View Stats", systemImage: "chart.bar.fill")
        }
        Button {
            onAction?(.share)
        } label: {
            Label("Share Streak", systemImage: "square.and.arrow.up")
        }
        Divider()
        Button("Reset Progress", role: .destructive) { showingResetConfirmation = true }
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
        // Edits apply to the model live — swipe-dismiss would silently keep
        // them while skipping both CANCEL's restore and SAVE's widget sync
        .interactiveDismissDisabled()
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
    case share
    case stats
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

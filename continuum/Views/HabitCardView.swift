import SwiftUI
import SwiftData

struct HabitCardView: View {
    @Bindable var habit: Habit
    var refreshTrigger: Bool = false
    /// Habits done today and in total — the day's last completion plays a chord.
    var completedTodayCount: Int = 0
    var habitCount: Int = 1
    /// Bumped by ContentView when the day's last habit is done.
    var perfectDaySweep: Int = 0
    var onAction: ((HabitAction) -> Void)? = nil
    var onCompletion: ((Bool) -> Void)? = nil
    /// Milestone/record/health celebration shown inside this tile. Full-screen
    /// takeovers are reserved for graduation and the app-wide moments.
    var celebration: TileCelebration? = nil
    var onCelebrationTap: (() -> Void)? = nil

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

    // Tap-then-hold backfills yesterday. The tap's own feedback (hint / undo)
    // waits out the window so a second press can't land on the undo button.
    @State private var lastTapAt: Date?
    @State private var pendingTapFeedback: UUID?
    /// Non-nil while the current hold is filling in yesterday instead of today.
    @State private var backfillDate: Date?
    private let tapHoldWindow: Double = 0.35

    // Hint / undo states
    @State private var showHoldHint = false
    @State private var showUndoConfirm = false

    // Reset confirmation
    @State private var showingResetConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Completion animation states
    @State private var showCompletionEffect = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var centerIconScale: CGFloat = 0
    @State private var centerIconOpacity: Double = 0
    // Completion ripple: bumping the token rolls a swell through the filled
    // days, starting at the day just marked
    @State private var rippleToken = 0
    @State private var rippleOrigin = 0

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

    private var displayStreak: Int { habit.displayStreak }

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
                    // Border traces itself as you hold
                    if isAnimatingCompletion {
                        completionProgressOverlay
                    }
                }
                .overlay {
                    PerfectDaySweep(trigger: perfectDaySweep, cornerRadius: cornerRadius)
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

            if let celebration {
                celebrationOverlay(celebration)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .zIndex(10)
            }
        }
        // Single tap — share the moment, else undo if completed, else hint
        .onTapGesture {
            if let celebration {
                if celebration.isShareable {
                    SoundManager.shared.triggerSelectionHaptic()
                    onCelebrationTap?()
                }
                return
            }
            lastTapAt = Date()
            let token = UUID()
            pendingTapFeedback = token
            DispatchQueue.main.asyncAfter(deadline: .now() + tapHoldWindow) {
                // A press started inside the window: it's a tap-hold, not a tap
                guard pendingTapFeedback == token else { return }
                pendingTapFeedback = nil
                showTapFeedback()
            }
        }
        // Hold to complete — the fill bar tracks the press; release early to cancel.
        // Tap first, then hold, to fill in yesterday.
        .onLongPressGesture(minimumDuration: holdToCompleteDuration, maximumDistance: 40) {
            if isAnimatingCompletion {
                finishCompletion()
            }
        } onPressingChanged: { pressing in
            if pressing {
                let isTapHold = lastTapAt.map { Date().timeIntervalSince($0) < tapHoldWindow } ?? false
                lastTapAt = nil
                pendingTapFeedback = nil
                guard !isAnimatingCompletion else { return }
                if isTapHold, let yesterday = yesterdayIfMissed {
                    startCompletion(backfilling: yesterday)
                } else if !habit.isCompletedToday {
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
        .accessibilityAction(named: "Complete yesterday") {
            guard !isAnimatingCompletion, let yesterday = yesterdayIfMissed else { return }
            backfillDate = yesterday
            finishCompletion()
        }
    }

    /// Yesterday, if it hasn't been marked done yet.
    private var yesterdayIfMissed: Date? {
        guard let yesterday = ContinuumDay.calendar.date(byAdding: .day, value: -1, to: Date()),
              !habit.isCompleted(on: yesterday) else { return nil }
        return yesterday
    }

    private func showTapFeedback() {
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
        // Border lives outside the clip so it renders at full width and the
        // completed-state glow isn't cut off. strokeBorder draws inward.
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    themeColor.opacity(habit.isCompletedToday ? 0.9 : 0.16),
                    lineWidth: habit.isCompletedToday ? 2.5 : 1
                )
        )
        .shadow(
            color: themeColor.opacity(habit.isCompletedToday ? 0.35 : 0),
            radius: 10
        )
        .overlay {
            if habit.isCompletedToday {
                TiltSheenBorder(cornerRadius: cornerRadius, lineWidth: 2.5)
                    .transition(.opacity)
            }
        }
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
                    .animation(.easeOut(duration: 0.6), value: health)
                    .overlay {
                        TiltSheenFill(intensity: 0.7)
                            .mask {
                                Circle()
                                    .trim(from: 0, to: health)
                                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                            }
                    }

                Text("\(healthPercentage)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor)
                    .contentTransition(.numericText(value: Double(healthPercentage)))
                    .animation(.snappy, value: healthPercentage)
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
                    .contentTransition(.numericText())
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
                                .keyframeAnimator(initialValue: RippleFrame(), trigger: rippleToken) { dot, frame in
                                    dot.scaleEffect(frame.scale).brightness(filled ? frame.brightness : 0)
                                } keyframes: { _ in
                                    rippleKeyframes(for: idx)
                                }
                        }
                    }
                    .drawingGroup() // Render as single layer for better performance
                    // Filled days catch the light as the phone tilts
                    .overlay {
                        if flags.contains(true) {
                            TiltSheenFill()
                                .mask {
                                    LazyVGrid(columns: columns, spacing: spacing) {
                                        ForEach(0..<habitFormationDays, id: \.self) { idx in
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(flags[idx] ? Color.white : Color.clear)
                                                .frame(width: dotSize, height: dotSize)
                                        }
                                    }
                                    .drawingGroup()
                                }
                        }
                    }
                }
            }
    }

    /// Each square swells and brightens once, delayed by its distance from
    /// the day just marked, so the wave visibly rolls across the grid.
    private func rippleKeyframes(for idx: Int) -> some Keyframes<RippleFrame> {
        let dx = Double(idx % columnsCount - rippleOrigin % columnsCount)
        let dy = Double(idx / columnsCount - rippleOrigin / columnsCount)
        let delay = (dx * dx + dy * dy).squareRoot() * 0.045
        return KeyframeTrack(\RippleFrame.self) {
            // A zero-length keyframe yields NaN and the origin square vanishes
            LinearKeyframe(RippleFrame(), duration: max(delay, 0.01))
            SpringKeyframe(RippleFrame(scale: 1.35, brightness: 0.35), duration: 0.14, spring: .snappy)
            SpringKeyframe(RippleFrame(), duration: 0.4, spring: .bouncy)
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
        // Dark slate card background (darker than main bg).
        // The progress-color border is applied as an overlay in `body` so it
        // sits outside the clip shape and can render its full width + glow.
        Color(red: 0.10, green: 0.11, blue: 0.13)
    }

    // MARK: - Completion Progress Overlay

    private var completionProgressOverlay: some View {
        VStack {
            Spacer()
            if backfillDate != nil {
                Text("YESTERDAY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(themeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            // Two strokes leave the top centre and meet at the bottom as the
            // hold completes
            let lineWidth: CGFloat = 2.5
            let outline = CardOutline(cornerRadius: cornerRadius - lineWidth / 2)
            ZStack {
                outline.trim(from: 0, to: completionProgress / 2)
                    .stroke(themeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                outline.trim(from: 1 - completionProgress / 2, to: 1)
                    .stroke(themeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            .padding(lineWidth / 2)
            .shadow(color: themeColor.opacity(0.7), radius: 6)
        }
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

    // MARK: - Celebration Overlay (in-tile)

    /// Covers the tile's own bounds for ~2.4s. Same grammar as the full-screen
    /// cards — accent frame, one big number — at tile scale.
    private func celebrationOverlay(_ celebration: TileCelebration) -> some View {
        let accent = themeColor
        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.9))

            VStack(spacing: 2) {
                Text(celebration.value)
                    .font(.system(size: 46, weight: .heavy, design: .monospaced))
                    .foregroundStyle(accent)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(celebration.unit.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(accent.opacity(0.8))

                Text(celebration.caption)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 4)

                if celebration.isShareable {
                    Label("TAP TO SHARE", systemImage: "square.and.arrow.up")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 6)
                }
            }
            .padding(8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(accent.opacity(0.9), lineWidth: 2.5)
        )
        .shadow(color: accent.opacity(0.4), radius: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(celebration.value) \(celebration.unit) — \(celebration.caption) for \(habit.name)")
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

    private func startCompletion(backfilling date: Date? = nil) {
        isAnimatingCompletion = true
        backfillDate = date
        completionProgress = 0
        showHoldHint = false
        showUndoConfirm = false

        // A ladder of transients that tightens as the bar fills, instead of
        // one tick followed by 900ms of nothing
        SoundManager.shared.startHoldFeedback(duration: holdToCompleteDuration)

        // Press-down must be immediate: a slow one is the loudest
        // "sluggish app" tell there is
        withAnimation(.easeOut(duration: 0.1)) {
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
        backfillDate = nil
        // Rewind roughly 3x faster than it filled: the asymmetry is what makes
        // "nothing happened" legible
        withAnimation(.easeOut(duration: holdToCompleteDuration / 3)) {
            completionProgress = 0
        }
        withAnimation(.easeOut(duration: 0.18)) {
            cardScale = 1.0
        }
        SoundManager.shared.cancelHoldFeedback()
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

        SoundManager.shared.finishHoldFeedback()

        // Reduce Motion keeps the timing and the haptics, drops the travel
        withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.3, dampingFraction: 0.5)) {
            cardScale = reduceMotion ? 1.0 : (isRareCompletion ? 1.08 : 1.05)
            centerIconScale = 1.0
            centerIconOpacity = 1.0
            rippleScale = reduceMotion ? 1.0 : (isRareCompletion ? 11.0 : 8.0)
        }

        // One bell per completion; the day's last habit gets the chord
        let isBackfill = backfillDate != nil
        let isLastOfDay = !isBackfill && habitCount > 1 && completedTodayCount + 1 >= habitCount
        if isLastOfDay {
            SoundManager.shared.playDayCompleteChord()
            SoundManager.shared.triggerCompletionHaptic()
        } else if isRareCompletion {
            SoundManager.shared.playRareCompletionSound()
            SoundManager.shared.triggerRareHaptic()
        } else {
            SoundManager.shared.playCompletionBeep()
            SoundManager.shared.triggerCompletionHaptic()
        }

        if !reduceMotion {
            // A swell rolls out through the grid from the day just marked
            rippleOrigin = isBackfill ? 1 : 0
            rippleToken += 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                cardScale = 1.0
                rippleOpacity = 0
                centerIconOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showCompletionEffect = false
        }

        // Update data
        let healthBefore = healthPercentage
        if let backfillDate {
            habit.setCompleted(true, on: backfillDate)
            self.backfillDate = nil
        } else {
            habit.toggleCompletion()
        }

        let habitData = HabitData(from: habit)
        Task.detached(priority: .background) {
            HabitDataManager.shared.saveHabitData(habitData)
            HabitDataManager.shared.updateWidgetTimeline()
        }

        // Health dial clicks over, one tick per point, after the hit lands
        SoundManager.shared.triggerHealthTicks(healthPercentage - healthBefore, after: 0.3)

        // A backfill can extend the streak, so it's a completion too
        onCompletion?(true)
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
            // Marking today in history must silence today's reminder too
            if let context = habit.modelContext,
               let allHabits = try? context.fetch(FetchDescriptor<Habit>()) {
                NotificationManager.shared.sync(habits: allHabits)
            }
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

/// One grid square's state during the completion ripple.
struct RippleFrame: Animatable {
    var scale: CGFloat = 1
    var brightness: Double = 0

    var animatableData: AnimatablePair<CGFloat, Double> {
        get { AnimatablePair(scale, brightness) }
        set { scale = newValue.first; brightness = newValue.second }
    }
}

/// The card's rounded rectangle, drawn clockwise from the top centre, so a
/// trim from either end grows down both sides and meets at the bottom.
struct CardOutline: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                    startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// A band of light that crosses the card when every habit is done for the
/// day. Cards start in reading order, so the glint reads as one sweep
/// across the whole screen.
private struct PerfectDaySweep: View {
    let trigger: Int
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: CGFloat = -0.5

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(0.35), .white.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.5, height: geo.size.height * 2)
            .rotationEffect(.degrees(25))
            .position(x: geo.size.width * position, y: geo.size.height / 2)
            .onChange(of: trigger) {
                guard !reduceMotion else { return }
                let frame = geo.frame(in: .global)
                let delay = Double(frame.minX / 1000 + frame.minY / 2500)
                position = -0.5
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.7).delay(delay)) { position = 1.5 }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

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

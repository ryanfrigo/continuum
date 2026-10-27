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
    /// 0 → 1 breaks the card into squares and away, as it moves slot.
    var dissolve: Double = 0
    var onAction: ((HabitAction) -> Void)? = nil
    /// (completed, day key marked) — the day is today, or yesterday on a backfill.
    var onCompletion: ((Bool, Int) -> Void)? = nil
    /// Milestone, level or comeback celebration shown inside this tile. Full-screen
    /// takeovers are reserved for graduation and the app-wide moments.
    var celebration: TileCelebration? = nil
    var onCelebrationTap: (() -> Void)? = nil

    // Visual constants
    private let cornerRadius: CGFloat = 20
    /// A week a row, four rows: the last 28 days
    private let columnsCount: Int = 7
    private let gridDays: Int = HabitMath.gridDays

    // Sheet states

    // Animation states
    @State private var lastRefreshDate = Date()
    @State private var cardScale: CGFloat = 1.0

    // Completion progress states
    @State private var isAnimatingCompletion = false
    @State private var completionProgress: CGFloat = 0

    // Tap-then-hold backfills yesterday. The tap's feedback (hint / undo)
    // shows at once; a second press inside the window clears it, and the undo
    // button ignores presses that soon so that press can't land on it.
    @State private var lastTapAt: Date?
    /// Bumped per tap so an older tap's auto-hide can't cut a newer one short.
    @State private var tapFeedbackToken = 0
    @State private var undoShownAt = Date.distantPast
    /// Non-nil while the current hold is filling in yesterday instead of today.
    @State private var backfillDate: Date?
    private let tapHoldWindow: Double = 0.35

    // Hint / undo states
    @State private var showHoldHint = false
    @State private var showUndoConfirm = false

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

    // Variable reward: ~1 in 15 completions adds sparkles and a second ripple
    @State private var isRareCompletion = false
    private let goldColor = HabitPalette.gold

    /// Every completion lands in gold; the rare ones just get more of it.
    private var effectColor: Color { goldColor }

    /// True for the few seconds after marking today: the card shines gold,
    /// then eases into its done look so attention moves to what's left.
    @State private var justCompleted = false
    /// Bumps per completion so an old fade can't cut a newer one short.
    @State private var completionGeneration = 0
    /// Bumps per completion: fires the gold sweep.
    @State private var burstToken = 0
    /// 0 → 1 across the shockwave and fractal bloom; 1 at rest (shaders off).
    @State private var bloomProgress: Double = 1
    /// What the hold just earned ("+3%", or "+1 DAY" at the top), floating up.
    @State private var gainText: String?
    @State private var gainRise: CGFloat = 0
    @State private var gainOpacity: Double = 0
    private let successHold: Double = 1.5
    private let doneFade: Double = 1.2

    /// Mid-celebration (an undo during it ends it on the spot).
    private var celebrating: Bool { justCompleted && habit.isCompletedToday }

    /// 0 while a habit is open or celebrating, 1 once it has settled as done.
    private var doneAmount: Double {
        habit.isCompletedToday && !justCompleted ? 1 : 0
    }

    // MARK: - Computed Properties

    private var consistency: ConsistencyTally {
        habit.consistency
    }

    private var themeColor: Color {
        HabitPalette.color(HabitMath.colorProgress(habit.consistency))
    }

    /// Gold while the completion lands, a quiet line once done, faint while open.
    private var borderColor: Color {
        if celebrating { return goldColor.opacity(0.95) }
        return themeColor.opacity(habit.isCompletedToday ? 0.9 : 0.2)
    }

    /// Days back to the first done day. Older cells aren't misses — the habit
    /// hadn't started — so they draw fainter. Nil when nothing's done yet.
    private var daysSinceStart: Int? {
        habit.completedDayKeys.min().map { ContinuumDay.daysBetween($0, ContinuumDay.todayKey()) }
    }

    private var paddedFlags: [Bool] {
        // Reverse so index 0 = today, the last index = oldest
        Array(habit.historyCompletionFlags().reversed())
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
                .modifier(CompletionBloomEffect(progress: bloomProgress, cornerRadius: cornerRadius))
                .modifier(PixelDissolveEffect(progress: dissolve))
                // Outside the shader: a system menu can't be drawn through one.
                // Tucked into the corner, centred on the title's first line.
                .overlay(alignment: .topTrailing) {
                    optionsMenu.padding(.top, 10).padding(.trailing, 2)
                        .opacity(1 - dissolve)
                }
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
                .overlay {
                    PerfectDaySweep(trigger: burstToken, cornerRadius: cornerRadius,
                                    color: goldColor, staggered: false)
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
            showTapFeedback()
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
        // Broken up and moving: nothing there to tap or hold
        .allowsHitTesting(dissolve == 0)
        .onAppear {
            lastRefreshDate = Date()
        }
        .onChange(of: refreshTrigger) { lastRefreshDate = Date() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: habit.isCompletedToday ? "Undo today" : "Mark today done") {
            if habit.isCompletedToday {
                habit.toggleCompletion()
                let habitData = HabitData(from: habit)
                Task.detached(priority: .background) {
                    HabitDataManager.shared.saveHabitData(habitData)
                    HabitDataManager.shared.updateWidgetTimeline()
                }
                onCompletion?(false, ContinuumDay.todayKey())
            } else if !isAnimatingCompletion {
                finishCompletion()
            }
        }
        .accessibilityAction(named: "Mark yesterday done") {
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
        tapFeedbackToken += 1
        let token = tapFeedbackToken
        if habit.isCompletedToday {
            SoundManager.shared.triggerSelectionHaptic()
            undoShownAt = Date()
            withAnimation(.snappy(duration: 0.18)) {
                showUndoConfirm = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                guard token == tapFeedbackToken else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    showUndoConfirm = false
                }
            }
        } else if !isAnimatingCompletion {
            SoundManager.shared.triggerSelectionHaptic()
            withAnimation(.snappy(duration: 0.18)) {
                showHoldHint = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                guard token == tapFeedbackToken else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    showHoldHint = false
                }
            }
        }
    }

    private var accessibilitySummary: String {
        var parts = [habit.name]
        if let percent = consistency.percent { parts.append("\(percent) percent consistent") }
        if let trend = habit.consistencyTrend, trend != 0 {
            parts.append(trend > 0 ? "up \(trend) points this week" : "down \(-trend) points this week")
        }
        parts.append(habit.isCompletedToday ? "done today" : "not done today")
        if habit.isStrong { parts.append("habit strong") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name and options
            headerSection

            // Done for today, the number and grid step back; the name stays
            // bright, struck through
            Group {
                // The number: consistency over the grid, and this week's change
                consistencySection

                // Four-week grid — hero visual, gets remaining space
                historyGridSection
            }
            .opacity(1 - 0.4 * doneAmount)
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        // Border lives outside the clip so it renders at full width and the
        // completed-state glow isn't cut off. strokeBorder draws inward.
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    borderColor,
                    lineWidth: habit.isCompletedToday ? 3 : 1.5
                )
        )
        .shadow(
            color: celebrating ? goldColor.opacity(0.55) : themeColor.opacity(habit.isCompletedToday ? 0.35 : 0),
            radius: 10
        )
        .overlay {
            if habit.isCompletedToday {
                TiltSheenBorder(cornerRadius: cornerRadius, lineWidth: 3)
                    .transition(.opacity)
            }
        }
    }

    private var headerSection: some View {
        // Nearly the full width: the options menu overlays the corner
        Text(habit.name)
            .strikethrough(doneAmount > 0, color: .white.opacity(0.7))
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Options menu (was the long-press context menu — long press now
    /// completes the habit). A small glyph in the top corner with a bigger
    /// tap area than it looks.
    private var optionsMenu: some View {
        Menu {
            contextMenuContent
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.45))
                .frame(width: 30, height: 22)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Options for \(habit.name)")
    }

    private var consistencySection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let percent = consistency.percent {
                percentText(percent)
                    .foregroundStyle(themeColor)

                    // The number catches the light as the phone tilts
                    .overlay {
                        TiltSheenFill(intensity: 0.6)
                            .mask { percentText(percent) }
                    }

                if let trend = habit.consistencyTrend, trend != 0 {
                    TrendLabel(trend: trend, size: 10)
                }
            } else {
                Text("Hold to start")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            Spacer(minLength: 0)

            if habit.isStrong {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(HabitPalette.gold)
            }
        }
        // Same height with or without a number, so neighbouring cards line up
        .frame(height: 16, alignment: .bottom)
        // What the hold just earned, rising off the row
        .overlay {
            if let gainText {
                Text(gainText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(goldColor)
                    .shadow(color: goldColor.opacity(0.7), radius: 6)
                    .fixedSize()
                    .offset(y: -gainRise)
                    .opacity(gainOpacity)
                    .allowsHitTesting(false)
            }
        }
    }

    /// A readout, not a headline: the app's own mono at text size.
    private func percentText(_ percent: Int) -> some View {
        Text("\(percent)%")
            .font(.system(size: 13, weight: .semibold))
            .contentTransition(.numericText(value: Double(percent)))
            .animation(.snappy, value: percent)
    }

    private var historyGridSection: some View {
        // Grid is 7 columns × 4 rows with 3pt spacing
        // Aspect ratio: (7*d + 6*3) / (4*d + 3*3) ≈ 1.78 for typical dot sizes
        let gridAspectRatio: CGFloat = 1.78
        let flags = paddedFlags // Cache computed property
        let color = themeColor // Cache computed property
        let startIndex = daysSinceStart

        return Color.clear
            .aspectRatio(gridAspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let spacing: CGFloat = 3
                    let availableWidth = geo.size.width
                    let dotSize = floor((availableWidth - CGFloat(columnsCount - 1) * spacing) / CGFloat(columnsCount))
                    let columns = Array(repeating: GridItem(.fixed(dotSize), spacing: spacing), count: columnsCount)

                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(0..<gridDays, id: \.self) { idx in
                            let filled = flags[idx]
                            let isToday = idx == 0

                            RoundedRectangle(cornerRadius: 2)
                                .fill(isToday && filled && celebrating ? goldColor
                                      : dotColor(filled: filled, isToday: isToday,
                                                 notStarted: startIndex.map { idx > $0 } ?? true,
                                                 healthColor: color))
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
                                        ForEach(0..<gridDays, id: \.self) { idx in
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

    private func dotColor(filled: Bool, isToday: Bool, notStarted: Bool, healthColor: Color) -> Color {
        HabitPalette.cell(filled: filled, isToday: isToday, notStarted: notStarted, color: healthColor)
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
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
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
                Text("Hold to mark done")
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
                // A tap-hold's second press, not a deliberate undo
                if Date().timeIntervalSince(undoShownAt) < tapHoldWindow { return }
                // Actually undo
                SoundManager.shared.playUndo()
                habit.toggleCompletion()
                let habitData = HabitData(from: habit)
                Task.detached(priority: .background) {
                    HabitDataManager.shared.saveHabitData(habitData)
                    HabitDataManager.shared.updateWidgetTimeline()
                }
                onCompletion?(false, ContinuumDay.todayKey())
                withAnimation(.easeOut(duration: 0.2)) {
                    showUndoConfirm = false
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Tap to undo")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(themeColor.opacity(0.5))
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

        if !reduceMotion {
            burstToken += 1
            SoundManager.shared.triggerBloomSwell()
            bloomProgress = 0
            withAnimation(.easeOut(duration: 1.8)) { bloomProgress = 1 }
        }

        // Gold for a moment, then ease into the done look
        if !isBackfill {
            completionGeneration += 1
            let generation = completionGeneration
            justCompleted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + successHold) {
                guard generation == completionGeneration else { return }
                withAnimation(.easeInOut(duration: doneFade)) {
                    justCompleted = false
                }
            }
        }

        // Update data
        let percentBefore = consistency.percent ?? 0
        let markedKey = ContinuumDay.key(for: backfillDate ?? Date())
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

        // The number clicks over, one tick per point, after the hit lands
        let gain = (consistency.percent ?? 0) - percentBefore
        SoundManager.shared.triggerHealthTicks(gain, after: 0.3)
        showGain(gain > 0 ? "+\(gain)%" : "+1 DAY")

        // A backfill moves the number and the days done, so it's a completion too
        onCompletion?(true, markedKey)
    }

    /// The gain floats up off the number, then fades.
    private func showGain(_ text: String) {
        gainRise = 0
        gainOpacity = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            gainText = text
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { gainOpacity = 1 }
            withAnimation(.easeOut(duration: 1.4)) { gainRise = 9 }
            withAnimation(.easeIn(duration: 0.5).delay(1.0)) { gainOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if gainText == text { gainText = nil }
            }
        }
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
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Divider()
        Button {
            onAction?(.editName)
        } label: {
            Label("Edit Name", systemImage: "pencil")
        }
        Button {
            onAction?(.editHistory)
        } label: {
            Label("Edit History", systemImage: "calendar")
        }
        Button {
            onAction?(.archive)
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        Divider()
        Button(role: .destructive) {
            onAction?(.confirmErase)
        } label: {
            Label("Erase History", systemImage: "eraser")
        }
        Button(role: .destructive) {
            onAction?(.confirmDelete)
        } label: {
            Label("Delete Habit", systemImage: "trash")
        }
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
    var color: Color = .white
    /// Perfect-day sweeps ripple across the grid by position; a single card's doesn't.
    var staggered = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: CGFloat = -0.5

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [color.opacity(0), color.opacity(0.35), color.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.5, height: geo.size.height * 2)
            .rotationEffect(.degrees(25))
            .position(x: geo.size.width * position, y: geo.size.height / 2)
            .onChange(of: trigger) {
                guard !reduceMotion else { return }
                let frame = geo.frame(in: .global)
                let delay = staggered ? Double(frame.minX / 1000 + frame.minY / 2500) : 0.05
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
    // These open a sheet or confirmation, which ContentView presents: one on
    // a cell of the lazy grid could stall until that card next changed.
    case editName
    case editHistory
    case confirmDelete
    case confirmErase
    case rename(String)
    case delete
    case archive
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


/// Breaks the card into squares (CompletionShaders.metal pixelDissolve).
private struct PixelDissolveEffect: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.visualEffect { view, proxy in
            view.layerEffect(
                ShaderLibrary.pixelDissolve(.float2(proxy.size), .float(Float(progress))),
                maxSampleOffset: CGSize(width: 6, height: 6),
                isEnabled: progress > 0
            )
        }
    }
}

/// The completion's shockwave and fractal bloom (CompletionShaders.metal).
/// Animatable, so a single withAnimation drives the shaders frame by frame
/// without swapping the card's view identity.
private struct CompletionBloomEffect: ViewModifier, Animatable {
    var progress: Double
    let cornerRadius: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = Float(progress)
        let active = progress < 1
        content
            .visualEffect { view, proxy in
                view.layerEffect(
                    ShaderLibrary.completionRipple(.float2(proxy.size), .float(t)),
                    maxSampleOffset: CGSize(width: 24, height: 24),
                    isEnabled: active
                )
            }
            .overlay {
                if active {
                    GeometryReader { proxy in
                        Rectangle()
                            .colorEffect(ShaderLibrary.completionBloom(.float2(proxy.size), .float(t)))
                    }
                    .blendMode(.plusLighter)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
    }
}

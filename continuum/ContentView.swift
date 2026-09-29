//
//  ContentView.swift
//  continuum
//
//  Created by Ryan Frigo on 10/6/25.
//

import SwiftUI
import SwiftData
import CoreData
import StoreKit
#if canImport(Inject)
import Inject
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Habit.order)]) private var habits: [Habit]

    @State private var showingAdd = false
    @State private var newHabitName: String = ""
    @State private var refreshTrigger = false
    @State private var showingSettings = false
    @State private var showingOnboarding = false

    // Celebration state. Milestones, records and health now celebrate inside
    // the habit's own tile; only graduation and the app-wide moments take over
    // the screen.
    @State private var tileCelebrations: [UUID: TileCelebration] = [:]
    /// Bumped when the day's last habit is done: every card sweeps a glint.
    @State private var perfectDaySweep = 0
    @State private var lastPerfectDaySweepKey: Int?

    // Reminder opt-in, asked once after the first completion
    @AppStorage("hasAskedForReminders") private var hasAskedForReminders = false
    @State private var showReminderPrompt = false
    @State private var pendingReminderPrompt = false

    // Graduation state
    @State private var showGraduation = false
    @State private var graduationHabitName: String = ""
    @State private var graduationHabit: Habit? = nil
    @State private var recordAccent: Color = .orange

    // Share state
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false

    // Stats state
    @State private var statsHabit: Habit? = nil

    // Perfect day / perfect week state
    @State private var showPerfectDay = false
    @State private var showPerfectWeek = false
    @State private var perfectWeekCount = 0

    @AppStorage("hasCompletedOnboarding") private var onboardingCompleted = false
    @AppStorage("hasCompletedWalkthrough") private var walkthroughCompleted = false
    @AppStorage("habitsFormedCount") private var habitsFormedCount = 0
    @AppStorage("reviewRequestedForMilestone") private var reviewRequestedForMilestone = 0
    // Frequency gates so celebrations stay special instead of daily nags
    @AppStorage("lastPerfectDayCelebrationKey") private var lastPerfectDayCelebrationKey = 0
    /// Minor milestones and comebacks: at most one a day across every habit.
    @AppStorage("lastMinorMilestoneCelebrationKey") private var lastSmallMomentKey = 0
    // Defer the StoreKit review sheet until the 21-day celebration is dismissed
    @State private var pendingReviewRequest = false
    @State private var showWalkthrough = false
    @Environment(\.requestReview) private var requestReview

    #if canImport(Inject)
    @ObserveInjection var inject
    #endif

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var sortedHabits: [Habit] {
        habits.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }

    private var hasHabits: Bool {
        !habits.isEmpty
    }

    private var completedTodayCount: Int {
        habits.filter { $0.isCompletedToday }.count
    }

    private var allCompletedToday: Bool {
        hasHabits && completedTodayCount == habits.count
    }

    /// Every habit pooled: total days done over total days counted, so a
    /// two-day-old habit at 100% can't outvote a year-old one.
    private var overall: (now: ConsistencyTally, weekAgo: ConsistencyTally) {
        let today = ContinuumDay.todayKey()
        return habits.reduce((ConsistencyTally(), ConsistencyTally())) { sum, habit in
            let keys = habit.completedDayKeys
            return (sum.0 + HabitMath.consistency(completed: keys, todayKey: today),
                    sum.1 + HabitMath.consistencyWeekAgo(completed: keys, todayKey: today))
        }
    }

    private var overallHealth: Double {
        overall.now.fraction
    }

    var body: some View {
        ZStack {
            // Ambient living background
            AmbientBackgroundView(healthPercentage: overallHealth)

            // Floating particles
            FloatingParticlesView(
                particleCount: 25,
                baseColor: Color(hue: 0.08 + overallHealth * 0.4, saturation: 0.7, brightness: 0.9)
            )
            .opacity(0.6)

            // Main content
            NavigationStack {
                ZStack {
                    Color.clear // Transparent to show ambient background

                    if hasHabits {
                        habitGridView
                    } else if onboardingCompleted {
                        emptyStateView
                    }



                    // Walkthrough overlay
                    if showWalkthrough {
                        WalkthroughOverlay {
                            walkthroughCompleted = true
                            showWalkthrough = false
                        }
                        .transition(.opacity)
                        .zIndex(99)
                    }

                    if showPerfectDay {
                        PerfectDayOverlay(
                            habitCount: habits.count,
                            accent: healthColor(for: overallHealth),
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showPerfectDay = false
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(98)
                    }

                    if showReminderPrompt {
                        ReminderPromptView(
                            accent: healthColor(for: overallHealth),
                            onEnable: { time in enableRemindersForAll(at: time) },
                            onDismiss: {
                                hasAskedForReminders = true
                                withAnimation(.easeOut(duration: 0.25)) { showReminderPrompt = false }
                            }
                        )
                        .transition(.opacity)
                        .zIndex(104)
                    }

                    if showGraduation {
                        HabitGraduationOverlay(
                            habitName: graduationHabitName,
                            accent: healthColor(for: graduationHabit?.consistency.fraction ?? 1.0),
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showGraduation = false
                                }
                            },
                            onShare: {
                                if let habit = graduationHabit {
                                    shareImage = ShareCardGenerator.generateImage(habit: habit, format: .story)
                                    showGraduation = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        showShareSheet = true
                                    }
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(101)
                    }

                    if showPerfectWeek {
                        PerfectWeekOverlay(
                            habitCount: habits.count,
                            weekCount: perfectWeekCount,
                            accent: healthColor(for: overallHealth),
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showPerfectWeek = false
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(98)
                    }

                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: AppStoreLink.shareItems(with: image))
            }
        }
        .sheet(item: $statsHabit) { habit in
            HabitStatsView(habit: habit)
        }
        .sheet(isPresented: $showingAdd) {
            AddHabitSheet(
                newHabitName: $newHabitName,
                healthColor: healthColor(for: overallHealth)
            ) { name in
                addHabit(name: name)
                showingAdd = false
            } onCancel: {
                showingAdd = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .onDisappear {
                    if !walkthroughCompleted && !showWalkthrough {
                        showWalkthrough = true
                    }
                }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(isPresented: $showingOnboarding) { selectedHabits in
                onboardingCompleted = true
                createSelectedHabits(selectedHabits)
                // Show walkthrough after onboarding
                if !walkthroughCompleted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showWalkthrough = true
                        }
                    }
                }
            }
        }
        .onAppear {
            if !onboardingCompleted {
                showingOnboarding = true
            }
            migrateAllHabitDates()      // legacy midnight dates → canonical (timezone-safe)
            dedupeHabits()              // merge CloudKit sync duplicates
            reconcileCompletions()      // per-day ledger → arrays (after dedupe)
            applyPendingWidgetToggles() // reconcile completions made from the widget
            initializeHabitOrders()
            syncAllHabitsToWidget()
            syncNotifications()
            NotificationManager.shared.clearBadge()
            refreshTrigger.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            applyPendingWidgetToggles()
            dedupeHabits()
            reconcileCompletions()
            syncAllHabitsToWidget()
            refreshTrigger.toggle()
            syncNotifications()
            NotificationManager.shared.clearBadge()
        }
        // CloudKit delivered changes while the app is open: merge them before
        // the last-writer-wins array value sticks on screen
        .onReceive(
            NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
        ) { _ in
            dedupeHabits()
            if reconcileCompletions() {
                syncAllHabitsToWidget()
                syncNotifications()
                refreshTrigger.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
            // App sitting open across midnight: refresh "today" everywhere
            refreshTrigger.toggle()
            syncNotifications()
            syncAllHabitsToWidget()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated icon
            ZStack {
                // Outer rings
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    .frame(width: 90, height: 90)

                // Center icon
                Image(systemName: "plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 12) {
                Text("No habits yet")
                    .font(.system(size: 24, weight: .semibold, design: .default))
                    .foregroundStyle(.white)

                Text("Create your first habit to begin\nbuilding better routines")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                newHabitName = ""
                showingAdd = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Create Habit")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.orange)
                )
            }

            Spacer()
        }
    }

    // MARK: - Habit Grid

    private var habitGridView: some View {
        let overall = self.overall
        return ScrollView {
            VStack(spacing: 0) {
                ConsistencyHeader(
                    tally: overall.now,
                    trend: HabitMath.trend(now: overall.now, weekAgo: overall.weekAgo),
                    doneToday: completedTodayCount,
                    habitCount: habits.count,
                    accent: healthColor(for: overall.now.fraction)
                )
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 14)

                // Habits grid
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(sortedHabits) { habit in
                        HabitCardView(
                            habit: habit,
                            refreshTrigger: refreshTrigger,
                            completedTodayCount: completedTodayCount,
                            habitCount: habits.count,
                            perfectDaySweep: perfectDaySweep,
                            onAction: { action in
                                handleHabitAction(action, for: habit)
                            },
                            onCompletion: { completed, dayKey in
                                checkForMilestones(habit: habit, completed: completed, dayKey: dayKey)
                            },
                            celebration: tileCelebrations[habit.id],
                            onCelebrationTap: {
                                tileCelebrations[habit.id] = nil
                                shareImage = ShareCardGenerator.generateImage(habit: habit, format: .story)
                                showShareSheet = true
                            }
                        )
                        // No drag-reorder here: long press is the completion
                        // gesture. Reordering lives in Settings → Reorder Habits.
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 100) // Extra padding for tab bar safety
            }
        }
        // Scroll (and bounce) only once the habits outgrow the screen
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    SoundManager.shared.triggerSelectionHaptic()
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .hidingSharedBackground()

            ToolbarItem(placement: .principal) {
                Text("Continuum")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    SoundManager.shared.triggerSelectionHaptic()
                    newHabitName = ""
                    showingAdd = true
                } label: {
                    let buttonColor = healthColor(for: overallHealth)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(buttonColor)
                        .shadow(color: buttonColor.opacity(0.3), radius: 8)
                }
            }
            .hidingSharedBackground()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.clear, for: .navigationBar)
    }

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

    // MARK: - Actions

    private func handleHabitAction(_ action: HabitAction, for habit: Habit) {
        switch action {
        case .reset:
            habit.resetProgress()
            syncHabitToWidget(habit)
            syncNotifications()
        case .setStreak(let n):
            habit.setCurrentStreak(n)
            syncHabitToWidget(habit)
            syncNotifications()
        case .rename(let newName):
            habit.name = newName
            syncHabitToWidget(habit)
            // Pending reminders still carry the old name — rebuild them
            syncNotifications()
        case .delete:
            // @Query may not drop the habit synchronously; plan without it
            NotificationManager.shared.sync(habits: habits.filter { $0.id != habit.id })
            // Clean up widget data
            var allIds = HabitDataManager.shared.getAllHabitIds()
            allIds.removeAll { $0 == habit.id }
            HabitDataManager.shared.saveAllHabitIds(allIds)
            HabitDataManager.shared.removeHabitData(for: habit.id)
            HabitDataManager.shared.updateWidgetTimeline()
            CompletionLedger.deleteMarks(for: [habit.id], in: modelContext)
            modelContext.delete(habit)
            try? modelContext.save()
        case .share:
            shareImage = ShareCardGenerator.generateImage(habit: habit, format: .story)
            showShareSheet = true
        case .stats:
            statsHabit = habit
        }
    }

    private func addHabit(name: String) {
        let habit = Habit(name: name)
        habit.order = (habits.map { $0.order ?? 0 }.max() ?? -1) + 1
        modelContext.insert(habit)
        try? modelContext.save()
        syncHabitToWidget(habit)
    }

    private func checkForMilestones(habit: Habit, completed: Bool, dayKey: Int) {
        // Completion silences today's nudges and disarms tomorrow's evening
        // alert; undo restores them. The planner derives both from the new state.
        syncNotifications()

        guard completed else { return }

        // Diff the habit either side of this mark: no remembered "previous"
        // values to go stale overnight or across launches
        let todayKey = ContinuumDay.todayKey()
        let after = habit.completedDayKeys
        let before = after.subtracting([dayKey])

        // Levels fire once per habit. A habit seen for the first time starts
        // from where it already is, so updating doesn't set off a tile for
        // every habit at once.
        let levelKey = "celebratedLevel.\(habit.id.uuidString)"
        let celebratedLevel = UserDefaults.standard.object(forKey: levelKey) as? Int
            ?? MilestoneDetector.level(of: HabitMath.consistency(completed: before, todayKey: todayKey))
            ?? 0

        let events = MilestoneDetector.events(
            before: before,
            after: after,
            markedKey: dayKey,
            todayKey: todayKey,
            isAlreadyGraduated: habit.isGraduated,
            smallMomentShownToday: lastSmallMomentKey == todayKey,
            highestLevelCelebrated: celebratedLevel
        )

        if events.contains(.graduation) {
            if habit.checkAndMarkGraduation() {
                habitsFormedCount += 1
                try? modelContext.save()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                graduationHabitName = habit.name
                graduationHabit = habit
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showGraduation = true
                }
            }
        }

        // One tile moment per completion; the detector lists them highest first
        let tileEvent = events.first { TileCelebration($0) != nil }
        if let tileEvent {
            if tileEvent.isSmallMoment { lastSmallMomentKey = todayKey }
            showTileCelebration(tileEvent, for: habit)
        }
        if case .level(let level)? = tileEvent {
            UserDefaults.standard.set(level, forKey: levelKey)
        } else if UserDefaults.standard.object(forKey: levelKey) == nil {
            UserDefaults.standard.set(celebratedLevel, forKey: levelKey)
        }

        // First completion ever: this is the moment to offer reminders, while
        // the app has just visibly worked. Nothing else brings people back.
        considerReminderPrompt()

        // StoreKit review prompt, never over a celebration. Ask at 7 days done
        // first, then 21. With a tile, ask once it clears; with nothing on
        // screen, ask shortly after; under a full-screen card, wait for a
        // quieter completion. iOS caps this at 3 prompts a year.
        let fullScreenComing = events.contains(.graduation) || (allCompletedToday && habits.count > 1)
        for milestone in [7, 21] where after.count >= milestone && reviewRequestedForMilestone < milestone {
            if tileEvent != nil {
                reviewRequestedForMilestone = milestone
                pendingReviewRequest = true
            } else if !fullScreenComing {
                reviewRequestedForMilestone = milestone
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { requestReview() }
            }
            break
        }

        // Check for perfect day / perfect week (all habits complete).
        // With one habit every completion is "perfect" — the completion
        // animation is celebration enough, so these need 2+ habits.
        if allCompletedToday && habits.count > 1 {
            // Once a day: the glint crosses every card as the completion lands
            if lastPerfectDaySweepKey != ContinuumDay.todayKey() {
                lastPerfectDaySweepKey = ContinuumDay.todayKey()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    perfectDaySweep += 1
                    SoundManager.shared.triggerPerfectDayHaptic()
                }
            }

            // A tile celebration is scheduled 0.8s out, so checking whether one
            // is on screen right now always says "no" — ask the events instead
            let delay: Double = showGraduation ? 3.0
                : (tileEvent != nil ? 0.8 + TileCelebration.duration + 0.4 : 1.2)

            // 7, 14, 21... consecutive perfect days = perfect week(s)
            let perfectRun = HabitMath.consecutivePerfectDays(
                habits: habits.map { ($0.completedDayKeys, ContinuumDay.key(forStorage: $0.createdAt)) },
                asOfKey: ContinuumDay.todayKey()
            )

            if perfectRun > 0 && perfectRun % 7 == 0 {
                perfectWeekCount = perfectRun / 7
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    guard !showPerfectWeek else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showPerfectWeek = true
                    }
                }
            } else if lastPerfectDayCelebrationKey != ContinuumDay.todayKey() {
                // At most once per day — undo/redo must not re-trigger it
                lastPerfectDayCelebrationKey = ContinuumDay.todayKey()
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    guard !showPerfectDay else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showPerfectDay = true
                    }
                }
            }
        }
    }

    private func initializeHabitOrders() {
        var needsSave = false
        for (index, habit) in sortedHabits.enumerated() {
            if habit.order == nil {
                habit.order = index
                needsSave = true
            }
        }
        if needsSave { try? modelContext.save() }
    }

    private func createSelectedHabits(_ habitNames: [String]) {
        guard !habitNames.isEmpty else { return }
        for (index, name) in habitNames.enumerated() {
            let habit = Habit(name: name, order: index)
            modelContext.insert(habit)
            syncHabitToWidget(habit)
        }
        try? modelContext.save()
    }

    private func syncHabitToWidget(_ habit: Habit) {
        let habitData = HabitData(from: habit)
        HabitDataManager.shared.saveHabitData(habitData)
        var allIds = HabitDataManager.shared.getAllHabitIds()
        if !allIds.contains(habit.id) {
            allIds.append(habit.id)
            HabitDataManager.shared.saveAllHabitIds(allIds)
        }
        HabitDataManager.shared.updateWidgetTimeline()
    }

    private func syncAllHabitsToWidget() {
        // Sync all current habits to widget
        let allIds = habits.map { $0.id }
        HabitDataManager.shared.saveAllHabitIds(allIds)

        for habit in habits {
            let habitData = HabitData(from: habit)
            HabitDataManager.shared.saveHabitData(habitData)
        }

        HabitDataManager.shared.updateWidgetTimeline()
    }

    /// Ask about reminders once, after the first completion. The system
    /// permission dialog is only triggered if they tap REMIND ME, so a "not
    /// now" doesn't spend the single prompt iOS allows.
    private func considerReminderPrompt() {
        let completions = habits.reduce(0) { $0 + $1.completedDayKeys.count }
        let anyEnabled = habits.contains { $0.reminderEnabled }
        guard !hasAskedForReminders, !anyEnabled, completions == 1 else { return }

        Task {
            let status = await NotificationManager.shared.checkPermissionStatus()
            guard ReminderPrompt.shouldAsk(
                alreadyAsked: hasAskedForReminders,
                permission: status,
                anyReminderEnabled: anyEnabled,
                totalCompletions: completions
            ) else { return }
            // Let the day-one tile card land first
            try? await Task.sleep(nanoseconds: UInt64((TileCelebration.duration + 1.4) * 1_000_000_000))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showReminderPrompt = true
            }
        }
    }

    private func enableRemindersForAll(at time: Date) {
        hasAskedForReminders = true
        withAnimation(.easeOut(duration: 0.25)) { showReminderPrompt = false }

        Task {
            let granted = await NotificationManager.shared.requestPermission()
            guard granted else { return }
            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            for habit in habits {
                habit.reminderEnabled = true
                habit.reminderHour = components.hour ?? ReminderPrompt.defaultHour
                habit.reminderMinute = components.minute ?? ReminderPrompt.defaultMinute
            }
            try? modelContext.save()
            syncNotifications()
        }
    }

    /// Show a celebration inside the habit's tile, then clear it. Each tile
    /// keeps its own, so two habits finishing together both celebrate instead
    /// of queueing behind one full-screen card.
    private func showTileCelebration(_ event: CelebrationEvent, for habit: Habit) {
        guard let celebration = TileCelebration(event) else { return }
        let habitId = habit.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Full-screen cards get this via CelebrationCard.start(); without
            // it the in-tile versions are felt-less copies of the same moment
            SoundManager.shared.triggerCelebrationHaptic()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                tileCelebrations[habitId] = celebration
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + TileCelebration.duration) {
                // Only clear our own: a newer celebration may have replaced it,
                // and a share tap may have cleared it already.
                guard tileCelebrations[habitId]?.id == celebration.id else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    tileCelebrations[habitId] = nil
                }
                if pendingReviewRequest {
                    pendingReviewRequest = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        requestReview()
                    }
                }
            }
        }
    }

    private func syncNotifications() {
        NotificationManager.shared.sync(habits: habits)
    }

    // MARK: - Data Integrity

    /// One-time (idempotent) migration of legacy midnight-local dates to
    /// canonical noon-UTC storage. Runs before anything reads streaks.
    private func migrateAllHabitDates() {
        var changed = false
        for habit in habits {
            if habit.migrateToCanonicalStorage() { changed = true }
        }
        if changed { try? modelContext.save() }
    }

    /// CloudKit can't enforce unique IDs, so a habit edited on two devices
    /// before first sync can arrive twice. Merge duplicates (union of
    /// histories) and delete the extras — no completions are ever lost.
    private func dedupeHabits() {
        let grouped = Dictionary(grouping: habits, by: { $0.id })
        var changed = false

        for (_, group) in grouped where group.count > 1 {
            // Keep the one with the longest history; absorb the rest into it.
            // The ordering must be deterministic and based only on SYNCED
            // fields: if two devices dedupe concurrently and pick different
            // keepers, each deletes the other's — and the habit is lost
            // everywhere once the deletes sync. (Completion-count alone ties
            // in the common "both devices marked today" case, and Swift's
            // sort is not stable.)
            let sorted = group.sorted { a, b in
                if a.completedDatesArray.count != b.completedDatesArray.count {
                    return a.completedDatesArray.count > b.completedDatesArray.count
                }
                if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
                return (a.completedDayKeys.min() ?? 0) < (b.completedDayKeys.min() ?? 0)
            }
            let keeper = sorted[0]
            for duplicate in sorted.dropFirst() {
                keeper.absorb(duplicate)
                modelContext.delete(duplicate)
            }
            changed = true
        }

        if changed { try? modelContext.save() }
    }

    @discardableResult
    private func reconcileCompletions() -> Bool {
        CompletionLedger.reconcile(habits: habits, in: modelContext)
    }

    /// Apply completions/uncompletions made from the interactive widget.
    /// The widget already updated its own snapshot optimistically; here we
    /// bring SwiftData (the source of truth) up to date and fire milestones.
    private func applyPendingWidgetToggles() {
        let pending = HabitDataManager.shared.drainPendingToggles()
        guard !pending.isEmpty else { return }

        var touched = false
        var unapplied: [PendingHabitToggle] = []
        for toggle in pending {
            // A very old toggle must not override edits the user made since.
            guard Date().timeIntervalSince(toggle.timestamp) < 48 * 3600 else { continue }
            guard let habit = habits.first(where: { $0.id == toggle.habitId }) else {
                // On a cold launch the CloudKit-backed @Query can still be
                // empty — keep the toggle for the next activation instead of
                // silently discarding the user's completion.
                unapplied.append(toggle)
                continue
            }
            let already = habit.completedDayKeys.contains(toggle.dayKey)
            guard already != toggle.completed else { continue }

            habit.setCompleted(toggle.completed, forDayKey: toggle.dayKey)
            touched = true

            // Surface celebrations/graduation for today's completions
            if toggle.completed && toggle.dayKey == ContinuumDay.todayKey() {
                checkForMilestones(habit: habit, completed: true, dayKey: toggle.dayKey)
            }
        }

        if touched {
            try? modelContext.save()
        }
        HabitDataManager.shared.requeuePendingToggles(unapplied)
    }
}

#Preview {
    ContentView()
}

// MARK: - Toolbar

private extension ToolbarContent {
    /// iOS 26 wraps toolbar items in a Liquid Glass capsule; the icons read
    /// cleaner bare.
    @ToolbarContentBuilder
    func hidingSharedBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

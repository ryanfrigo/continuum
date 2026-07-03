//
//  ContentView.swift
//  continuum
//
//  Created by Ryan Frigo on 10/6/25.
//

import SwiftUI
import SwiftData
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

    // Celebration state
    @State private var celebrationMilestone: StreakMilestone? = nil
    @State private var celebrationHabitName: String = ""
    @State private var celebrationAccent: Color = .orange
    @State private var healthMilestonePercentage: Int? = nil
    @State private var healthMilestoneHabitName: String = ""
    @State private var healthMilestoneAccent: Color = .orange

    // Graduation state
    @State private var showGraduation = false
    @State private var graduationHabitName: String = ""
    @State private var graduationHabit: Habit? = nil

    // Share state
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false

    // Stats state
    @State private var statsHabit: Habit? = nil

    // Perfect day / perfect week state
    @State private var showPerfectDay = false
    @State private var showPerfectWeek = false
    @State private var perfectWeekCount = 0

    // Freeze save state (a freeze rescued a streak overnight)
    struct FreezeSave: Identifiable {
        let id = UUID()
        let habitName: String
        let streak: Int
        let freezesLeft: Int
    }
    @State private var freezeSave: FreezeSave? = nil

    // Personal record state
    @State private var recordHabitName: String = ""
    @State private var recordStreak: Int? = nil

    // Track previous streaks/health to detect milestone crossings
    @State private var previousStreaks: [UUID: Int] = [:]
    @State private var previousHealth: [UUID: Int] = [:]
    @State private var previousBest: [UUID: Int] = [:]   // all-time longest, for records

    @AppStorage("hasCompletedOnboarding") private var onboardingCompleted = false
    @AppStorage("hasCompletedWalkthrough") private var walkthroughCompleted = false
    @AppStorage("habitsFormedCount") private var habitsFormedCount = 0
    @AppStorage("reviewRequestedForMilestone") private var reviewRequestedForMilestone = 0
    // Frequency gates so celebrations stay special instead of daily nags
    @AppStorage("lastPerfectDayCelebrationKey") private var lastPerfectDayCelebrationKey = 0
    @AppStorage("lastMinorMilestoneCelebrationKey") private var lastMinorMilestoneCelebrationKey = 0
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

    // Calculate overall health for ambient background
    private var overallHealth: Double {
        guard !habits.isEmpty else { return 0 }
        let total = habits.reduce(0.0) { $0 + $1.habitHealth() }
        return total / Double(habits.count)
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

                    // Celebration overlays
                    if let milestone = celebrationMilestone {
                        CelebrationOverlay(
                            milestone: milestone,
                            habitName: celebrationHabitName,
                            accent: celebrationAccent,
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    celebrationMilestone = nil
                                }
                                if pendingReviewRequest {
                                    pendingReviewRequest = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        requestReview()
                                    }
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(100)
                    }

                    if let percentage = healthMilestonePercentage {
                        HealthMilestoneOverlay(
                            percentage: percentage,
                            habitName: healthMilestoneHabitName,
                            accent: healthMilestoneAccent,
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    healthMilestonePercentage = nil
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(100)
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
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showPerfectDay = false
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(98)
                    }

                    if showGraduation {
                        HabitGraduationOverlay(
                            habitName: graduationHabitName,
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
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showPerfectWeek = false
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(98)
                    }

                    if let save = freezeSave {
                        FreezeSaveOverlay(
                            habitName: save.habitName,
                            streak: save.streak,
                            freezesLeft: save.freezesLeft,
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    freezeSave = nil
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(102)
                    }

                    if let streak = recordStreak {
                        RecordOverlay(
                            habitName: recordHabitName,
                            streak: streak,
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    recordStreak = nil
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(103)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
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
            applyPendingWidgetToggles() // reconcile completions made from the widget
            initializeHabitOrders()
            initializeMilestoneTracking()
            syncAllHabitsToWidget()
            scheduleStreakAtRiskNotifications()
            rescheduleAllReminders()
            autoApplyStreakFreezes()
            grantWeeklyStreakFreezes()
            NotificationManager.shared.clearBadge()
            refreshTrigger.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            applyPendingWidgetToggles()
            dedupeHabits()
            // iOS keeps apps suspended for days — a missed day must be
            // rescued here too, not just on cold launch (onAppear)
            autoApplyStreakFreezes()
            grantWeeklyStreakFreezes()
            syncAllHabitsToWidget()
            refreshTrigger.toggle()
            scheduleStreakAtRiskNotifications()
            rescheduleAllReminders()
            NotificationManager.shared.clearBadge()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
            // App sitting open across midnight: refresh "today" everywhere
            autoApplyStreakFreezes()
            refreshTrigger.toggle()
            scheduleStreakAtRiskNotifications()
            rescheduleAllReminders()
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
        ScrollView {
            VStack(spacing: 0) {
                // Header section - no top spacing
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                // Habits grid
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(sortedHabits) { habit in
                        HabitCardView(
                            habit: habit,
                            refreshTrigger: refreshTrigger
                        ) { action in
                            handleHabitAction(action, for: habit)
                        } onCompletion: { completed in
                            checkForMilestones(habit: habit, wasJustCompleted: completed)
                        }
                        // No drag-reorder here: long press is the completion
                        // gesture. Reordering lives in Settings → Reorder Habits.
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 100) // Extra padding for tab bar safety
            }
        }
        // Always allow scrolling — content height varies with device size and Dynamic Type
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.clear, for: .navigationBar)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Text(dateString)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))

                    if habitsFormedCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                            Text("\(habitsFormedCount) formed")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color(hue: 0.12, saturation: 0.8, brightness: 0.95))
                    }
                }
            }

            Spacer()

            // Today's progress + overall health
            if !habits.isEmpty {
                VStack(alignment: .trailing, spacing: 6) {
                    // Overall health percentage
                    Text("\(Int(overallHealth * 100))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(healthColor(for: overallHealth))

                    // Today's completion count
                    HStack(spacing: 3) {
                        Text("\(completedTodayCount)/\(habits.count)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Text(allCompletedToday ? "perfect" : "today")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(allCompletedToday ? Color(hue: 0.12, saturation: 0.8, brightness: 0.95).opacity(0.7) : Color.white.opacity(0.35))
                    }
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    private var dateString: String {
        Self.dateFormatter.string(from: Date())
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
        case .setStreak(let n):
            habit.setCurrentStreak(n)
            syncHabitToWidget(habit)
        case .rename(let newName):
            habit.name = newName
            syncHabitToWidget(habit)
            // Pending reminders still carry the old name — rebuild them
            NotificationManager.shared.scheduleNotification(for: habit)
        case .delete:
            NotificationManager.shared.removeAllNotifications(for: habit)
            // Clean up widget data
            var allIds = HabitDataManager.shared.getAllHabitIds()
            allIds.removeAll { $0 == habit.id }
            HabitDataManager.shared.saveAllHabitIds(allIds)
            HabitDataManager.shared.removeHabitData(for: habit.id)
            HabitDataManager.shared.updateWidgetTimeline()
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
        previousStreaks[habit.id] = 0
        previousHealth[habit.id] = 0
    }

    private func checkForMilestones(habit: Habit, wasJustCompleted: Bool) {
        let previousStreak = previousStreaks[habit.id] ?? 0
        let previousHealthValue = previousHealth[habit.id] ?? 0

        // When a habit is completed, silence today's nudges (and arm
        // tomorrow's safety net — scheduleStreakAtRiskNotification handles both)
        if wasJustCompleted {
            NotificationManager.shared.scheduleStreakAtRiskNotification(for: habit)
            NotificationManager.shared.removeTodayReminder(for: habit)
        }

        guard wasJustCompleted else {
            // Undo: restore the reminders that completion just cancelled,
            // or the streak dies silently on a day the user showed intent
            NotificationManager.shared.scheduleNotification(for: habit)
            NotificationManager.shared.scheduleStreakAtRiskNotification(for: habit)
            previousStreaks[habit.id] = habit.currentStreak()
            previousHealth[habit.id] = Int(habit.habitHealth() * 100)
            return
        }

        let newStreak = habit.currentStreak()

        // Check for habit graduation (66 days) — special overlay
        if newStreak >= 66 && previousStreak < 66 {
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
        } else if let milestone = StreakMilestone.milestone(for: newStreak), newStreak > previousStreak {
            // Regular milestone celebration (skip 66 since graduation handles it).
            // Minor milestones (day 1/3/5) fire at most once per day — a new
            // user with several onboarding habits gets one card, not a queue.
            let minorAlreadyShownToday = milestone.isMinor
                && lastMinorMilestoneCelebrationKey == ContinuumDay.todayKey()
            if milestone != .habitFormed && !minorAlreadyShownToday {
                if milestone.isMinor {
                    lastMinorMilestoneCelebrationKey = ContinuumDay.todayKey()
                }
                let accent = healthColor(for: habit.habitHealth())
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    celebrationHabitName = habit.name
                    celebrationAccent = accent
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        celebrationMilestone = milestone
                    }
                }
            }
        }

        // StoreKit review prompt — ask after 21-day milestone, but only once
        // the celebration is dismissed so the sheet never covers the moment
        if newStreak >= 21 && reviewRequestedForMilestone < 21 {
            reviewRequestedForMilestone = 21
            pendingReviewRequest = true
        }

        // Grant a streak freeze at milestone achievements
        if newStreak == 7 || newStreak == 21 || newStreak == 100 {
            if previousStreak < newStreak {
                habit.grantStreakFreeze()
                try? modelContext.save()
            }
        }

        // Personal record — current streak beats the all-time best.
        // Floor of 7 so early days aren't constant "records"; skip when a
        // milestone celebration already fired for this same number.
        let allTimeBest = previousBest[habit.id] ?? 0
        if newStreak > allTimeBest {
            previousBest[habit.id] = newStreak
            if allTimeBest >= 7 && StreakMilestone.milestone(for: newStreak) == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    recordHabitName = habit.name
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        recordStreak = newStreak
                    }
                }
            }
        }

        let newHealth = Int(habit.habitHealth() * 100)
        let healthMilestones = [25, 50, 75, 100]
        for milestone in healthMilestones {
            if newHealth >= milestone && previousHealthValue < milestone {
                let delay = (celebrationMilestone != nil || showGraduation) ? 2.0 : 1.0
                let accent = healthColor(for: habit.habitHealth())
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    healthMilestoneHabitName = habit.name
                    healthMilestoneAccent = accent
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        healthMilestonePercentage = milestone
                    }
                }
                break
            }
        }

        previousStreaks[habit.id] = newStreak
        previousHealth[habit.id] = newHealth

        // Check for perfect day / perfect week (all habits complete).
        // With one habit every completion is "perfect" — the completion
        // animation is celebration enough, so these need 2+ habits.
        if wasJustCompleted && allCompletedToday && habits.count > 1 {
            let delay: Double = (celebrationMilestone != nil || showGraduation) ? 3.0 : 1.2

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

    private func initializeMilestoneTracking() {
        for habit in habits {
            previousStreaks[habit.id] = habit.currentStreak()
            previousHealth[habit.id] = Int(habit.habitHealth() * 100)
            previousBest[habit.id] = habit.longestStreak()
        }
    }

    private func createSelectedHabits(_ habitNames: [String]) {
        guard !habitNames.isEmpty else { return }
        for (index, name) in habitNames.enumerated() {
            let habit = Habit(name: name, order: index)
            modelContext.insert(habit)
            syncHabitToWidget(habit)
            previousStreaks[habit.id] = 0
            previousHealth[habit.id] = 0
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

    private func scheduleStreakAtRiskNotifications() {
        NotificationManager.shared.scheduleAllStreakAtRiskNotifications(habits: habits)
    }

    private func rescheduleAllReminders() {
        // Reschedule 7-day-ahead non-repeating reminders, skipping completed days
        for habit in habits where habit.reminderEnabled {
            NotificationManager.shared.scheduleNotification(for: habit)
        }
    }

    private func autoApplyStreakFreezes() {
        let todayKey = ContinuumDay.todayKey()
        let yesterdayKey = ContinuumDay.key(byAdding: -1, to: todayKey)
        let twoDaysAgoKey = ContinuumDay.key(byAdding: -2, to: todayKey)
        var didApply = false

        var firstSave: FreezeSave? = nil

        for habit in habits {
            guard habit.streakFreezeCount > 0 else { continue }

            // Check: yesterday was NOT completed/frozen, but the day before had a streak
            let completed = habit.completedDayKeys
            let frozen = habit.frozenDayKeys
            guard !completed.contains(yesterdayKey), !frozen.contains(yesterdayKey) else { continue }

            // Was there an active streak before yesterday?
            let streakBeforeYesterday = HabitMath.currentStreak(
                completed: completed,
                frozen: frozen,
                asOfKey: twoDaysAgoKey
            )
            if streakBeforeYesterday >= 3 {
                habit.useStreakFreeze()
                didApply = true

                // Surface the save — this is the moment freezes earn their keep
                if firstSave == nil {
                    let savedStreak = HabitMath.currentStreak(
                        completed: habit.completedDayKeys,
                        frozen: habit.frozenDayKeys,
                        asOfKey: yesterdayKey
                    )
                    firstSave = FreezeSave(
                        habitName: habit.name,
                        streak: savedStreak,
                        freezesLeft: habit.streakFreezeCount
                    )
                }
            }
        }

        if didApply {
            try? modelContext.save()
            if let save = firstSave {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        freezeSave = save
                    }
                }
            }
        }
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
                checkForMilestones(habit: habit, wasJustCompleted: true)
                NotificationManager.shared.removeStreakAtRiskNotification(for: habit)
                NotificationManager.shared.removeTodayReminder(for: habit)
            }
        }

        if touched {
            try? modelContext.save()
        }
        HabitDataManager.shared.requeuePendingToggles(unapplied)
    }

    private func grantWeeklyStreakFreezes() {
        let lastGrantKey = "lastStreakFreezeGrantDate"
        let lastGrant = UserDefaults.standard.object(forKey: lastGrantKey) as? Date ?? .distantPast
        let daysSinceGrant = Calendar.current.dateComponents([.day], from: lastGrant, to: Date()).day ?? 999

        if daysSinceGrant >= 7 {
            for habit in habits where habit.currentStreak() >= 7 {
                habit.grantStreakFreeze()
            }
            UserDefaults.standard.set(Date(), forKey: lastGrantKey)
            try? modelContext.save()
        }
    }
}

#Preview {
    ContentView()
}

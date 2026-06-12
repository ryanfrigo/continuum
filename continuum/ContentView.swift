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
    @State private var healthMilestonePercentage: Int? = nil
    @State private var healthMilestoneHabitName: String = ""

    // Graduation state
    @State private var showGraduation = false
    @State private var graduationHabitName: String = ""
    @State private var graduationHabit: Habit? = nil

    // Share state
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false

    // Perfect day state
    @State private var showPerfectDay = false

    // Track previous streaks/health to detect milestone crossings
    @State private var previousStreaks: [UUID: Int] = [:]
    @State private var previousHealth: [UUID: Int] = [:]

    @AppStorage("hasCompletedOnboarding") private var onboardingCompleted = false
    @AppStorage("hasCompletedWalkthrough") private var walkthroughCompleted = false
    @AppStorage("habitsFormedCount") private var habitsFormedCount = 0
    @AppStorage("reviewRequestedForMilestone") private var reviewRequestedForMilestone = 0
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
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    celebrationMilestone = nil
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
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
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
            refreshTrigger.toggle()
            scheduleStreakAtRiskNotifications()
            rescheduleAllReminders()
            NotificationManager.shared.clearBadge()
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
                        .draggable(habit.id.uuidString) {
                            dragPreview(for: habit)
                        }
                        .dropDestination(for: String.self) { items, _ in
                            handleDrop(items: items, onto: habit)
                        }
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

    // MARK: - Drag and Drop

    private func dragPreview(for habit: Habit) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.1))
            .frame(width: 140, height: 100)
            .overlay(
                Text(habit.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            )
    }

    private func handleDrop(items: [String], onto destination: Habit) -> Bool {
        guard let droppedId = items.first,
              let droppedUUID = UUID(uuidString: droppedId),
              let sourceHabit = habits.first(where: { $0.id == droppedUUID }),
              sourceHabit.id != destination.id else {
            return false
        }
        reorderHabit(from: sourceHabit, to: destination)
        return true
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

        // When a habit is completed, remove its streak-at-risk and today's reminder
        if wasJustCompleted {
            NotificationManager.shared.removeStreakAtRiskNotification(for: habit)
            NotificationManager.shared.removeTodayReminder(for: habit)
        }

        guard wasJustCompleted else {
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
            // Regular milestone celebration (skip 66 since graduation handles it)
            if milestone != .habitFormed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    celebrationHabitName = habit.name
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        celebrationMilestone = milestone
                    }
                }
            }
        }

        // StoreKit review prompt — ask after 21-day milestone
        if newStreak >= 21 && reviewRequestedForMilestone < 21 {
            reviewRequestedForMilestone = 21
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                requestReview()
            }
        }

        // Grant a streak freeze at milestone achievements
        if newStreak == 7 || newStreak == 21 || newStreak == 100 {
            if previousStreak < newStreak {
                habit.grantStreakFreeze()
                try? modelContext.save()
            }
        }

        let newHealth = Int(habit.habitHealth() * 100)
        let healthMilestones = [25, 50, 75, 100]
        for milestone in healthMilestones {
            if newHealth >= milestone && previousHealthValue < milestone {
                let delay = (celebrationMilestone != nil || showGraduation) ? 2.0 : 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    healthMilestoneHabitName = habit.name
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        healthMilestonePercentage = milestone
                    }
                }
                break
            }
        }

        previousStreaks[habit.id] = newStreak
        previousHealth[habit.id] = newHealth

        // Check for perfect day (all habits complete)
        if wasJustCompleted && allCompletedToday {
            let delay: Double = (celebrationMilestone != nil || showGraduation) ? 3.0 : 1.2
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard !showPerfectDay else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showPerfectDay = true
                }
            }
        }
    }

    private func reorderHabit(from source: Habit, to destination: Habit) {
        var ordered = sortedHabits
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == source.id }),
              let destIndex = ordered.firstIndex(where: { $0.id == destination.id }) else {
            return
        }

        ordered.remove(at: sourceIndex)
        ordered.insert(source, at: destIndex)

        for (index, habit) in ordered.enumerated() {
            habit.order = index
        }

        try? modelContext.save()
        SoundManager.shared.triggerSelectionHaptic()
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
        let today = Calendar.current.startOfDay(for: Date())
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today),
              let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today) else { return }

        let yesterdayStart = Calendar.current.startOfDay(for: yesterday)
        var didApply = false

        for habit in habits {
            guard habit.streakFreezeCount > 0 else { continue }

            // Check: yesterday was NOT completed, but 2 days ago WAS (streak just broke)
            let yesterdayCompleted = habit.completedDatesArray.contains {
                Calendar.current.isDate($0, inSameDayAs: yesterdayStart)
            }
            let alreadyFrozen = habit.freezeUsedDatesArray.contains {
                Calendar.current.isDate($0, inSameDayAs: yesterdayStart)
            }

            guard !yesterdayCompleted && !alreadyFrozen else { continue }

            // Was there an active streak before yesterday?
            let streakBeforeYesterday = habit.currentStreak(asOf: twoDaysAgo)
            if streakBeforeYesterday >= 3 {
                habit.useStreakFreeze()
                didApply = true
            }
        }

        if didApply {
            try? modelContext.save()
        }
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

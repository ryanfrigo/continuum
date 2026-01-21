//
//  ContentView.swift
//  continuum
//
//  Created by Ryan Frigo on 10/6/25.
//

import SwiftUI
import SwiftData
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
    @State private var hasCompletedOnboarding = false

    // Drag and drop state
    @State private var draggingHabit: Habit?
    @State private var dragOffset: CGSize = .zero

    // Celebration state
    @State private var celebrationMilestone: StreakMilestone? = nil
    @State private var celebrationHabitName: String = ""
    @State private var healthMilestonePercentage: Int? = nil
    @State private var healthMilestoneHabitName: String = ""

    // Track previous streaks/health to detect milestone crossings
    @State private var previousStreaks: [UUID: Int] = [:]
    @State private var previousHealth: [UUID: Int] = [:]

    @AppStorage("hasCompletedOnboarding") private var onboardingCompleted = false
    @AppStorage("hasCreatedDefaultHabits") private var defaultHabitsCreated = false

#if canImport(Inject)
    @ObserveInjection var inject
#endif

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var sortedHabits: [Habit] {
        habits.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }

    private var hasHabits: Bool {
        !habits.isEmpty
    }

    init() {}

    var body: some View {
        NavigationStack {
            ZStack {
                if !hasHabits && onboardingCompleted {
                    // Empty state - no habits yet
                    emptyStateView
                } else if hasHabits {
                    // Normal habit grid view
                    habitGridView
                }

                // Celebration overlays
                if let milestone = celebrationMilestone {
                    CelebrationOverlay(
                        milestone: milestone,
                        habitName: celebrationHabitName,
                        onDismiss: {
                            withAnimation {
                                celebrationMilestone = nil
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }

                if let percentage = healthMilestonePercentage {
                    HealthMilestoneOverlay(
                        percentage: percentage,
                        habitName: healthMilestoneHabitName,
                        onDismiss: {
                            withAnimation {
                                healthMilestonePercentage = nil
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddHabitSheet(newHabitName: $newHabitName) { name in
                addHabit(name: name)
                showingAdd = false
            } onCancel: {
                showingAdd = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(isPresented: $showingOnboarding) {
                onboardingCompleted = true
                // Create default habits after onboarding
                if !defaultHabitsCreated {
                    createDefaultHabits()
                    defaultHabitsCreated = true
                }
            }
        }
        .onAppear {
            // Show onboarding on first launch
            if !onboardingCompleted {
                showingOnboarding = true
            }

            // Initialize order for any habits that don't have one
            initializeHabitOrders()

            // Initialize tracking
            initializeMilestoneTracking()

            refreshTrigger.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshTrigger.toggle()
        }
    }

    // MARK: - Views

    private var emptyStateView: some View {
        GeometryReader { geometry in
            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)

                    Text("No Habits Yet")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Start building your first habit today")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }

                Button {
                    newHabitName = ""
                    showingAdd = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Your First Habit")
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.orange)
                    )
                }

                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black.ignoresSafeArea())
        }
    }

    private var habitGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(sortedHabits) { habit in
                    HabitCardView(habit: habit, refreshTrigger: refreshTrigger) { action in
                        switch action {
                        case .reset:
                            habit.resetProgress()
                        case .setStreak(let n):
                            habit.setCurrentStreak(n)
                        case .rename(let newName):
                            habit.name = newName
                        case .delete:
                            modelContext.delete(habit)
                            try? modelContext.save()
                        }
                    } onCompletion: { completed in
                        checkForMilestones(habit: habit, wasJustCompleted: completed)
                    }
                    .draggable(habit.id.uuidString) {
                        // Drag preview
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.orange.opacity(0.3))
                            .frame(width: 150, height: 150)
                            .overlay(
                                Text(habit.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            )
                    }
                    .dropDestination(for: String.self) { items, location in
                        guard let droppedId = items.first,
                              let droppedUUID = UUID(uuidString: droppedId),
                              let sourceHabit = habits.first(where: { $0.id == droppedUUID }),
                              sourceHabit.id != habit.id else {
                            return false
                        }

                        reorderHabit(from: sourceHabit, to: habit)
                        return true
                    }
                }
            }
            .padding(12)
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.gray)
                }
                .accessibilityLabel("Settings")
            }

            ToolbarItem(placement: .principal) {
                Text("Continuum")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    newHabitName = ""
                    showingAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.orange)
                }
                .accessibilityLabel("Add Habit")
            }
        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Actions

    private func addHabit(name: String) {
        let habit = Habit(name: name)
        habit.order = (habits.map { $0.order ?? 0 }.max() ?? -1) + 1
        modelContext.insert(habit)
        try? modelContext.save()

        // Sync to widget
        syncHabitToWidget(habit)

        // Initialize tracking for new habit
        previousStreaks[habit.id] = 0
        previousHealth[habit.id] = 0
    }

    private func checkForMilestones(habit: Habit, wasJustCompleted: Bool) {
        let previousStreak = previousStreaks[habit.id] ?? 0
        let previousHealthValue = previousHealth[habit.id] ?? 0

        // Only check for milestones if the habit was just completed (not uncompleted)
        guard wasJustCompleted else {
            // Still update tracking even when uncompleting
            previousStreaks[habit.id] = habit.currentStreak()
            previousHealth[habit.id] = Int(habit.habitHealth() * 100)
            return
        }

        // Check for streak milestone
        let newStreak = habit.currentStreak()
        if let milestone = StreakMilestone.milestone(for: newStreak), newStreak > previousStreak {
            // Small delay to let the completion animation play first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                celebrationHabitName = habit.name
                withAnimation {
                    celebrationMilestone = milestone
                }
            }
        }

        // Check for health milestone
        let newHealth = Int(habit.habitHealth() * 100)
        let healthMilestones = [25, 50, 75, 100]
        for milestone in healthMilestones {
            if newHealth >= milestone && previousHealthValue < milestone {
                // Stagger health celebration after streak celebration
                let delay = celebrationMilestone != nil ? 2.0 : 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    healthMilestoneHabitName = habit.name
                    withAnimation {
                        healthMilestonePercentage = milestone
                    }
                }
                break
            }
        }

        // Update tracking
        previousStreaks[habit.id] = newStreak
        previousHealth[habit.id] = newHealth
    }

    private func reorderHabit(from source: Habit, to destination: Habit) {
        var ordered = sortedHabits
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == source.id }),
              let destIndex = ordered.firstIndex(where: { $0.id == destination.id }) else {
            return
        }

        ordered.remove(at: sourceIndex)
        ordered.insert(source, at: destIndex)

        // Update order values
        for (index, habit) in ordered.enumerated() {
            habit.order = index
        }

        try? modelContext.save()

        // Haptic feedback
        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        #endif
    }

    private func initializeHabitOrders() {
        var needsSave = false
        for (index, habit) in sortedHabits.enumerated() {
            if habit.order == nil {
                habit.order = index
                needsSave = true
            }
        }
        if needsSave {
            try? modelContext.save()
        }
    }

    private func initializeMilestoneTracking() {
        for habit in habits {
            previousStreaks[habit.id] = habit.currentStreak()
            previousHealth[habit.id] = Int(habit.habitHealth() * 100)
        }
    }

    private func createDefaultHabits() {
        let defaultHabits = [
            ("Exercise", 0),
            ("Read", 1),
            ("Meditate", 2)
        ]

        for (name, order) in defaultHabits {
            let habit = Habit(name: name, order: order)
            modelContext.insert(habit)
            syncHabitToWidget(habit)
        }

        try? modelContext.save()
    }

    private func syncHabitToWidget(_ habit: Habit) {
        let habitData = HabitData(from: habit)
        HabitDataManager.shared.saveHabitData(habitData)

        // Update all habit IDs list
        var allIds = HabitDataManager.shared.getAllHabitIds()
        if !allIds.contains(habit.id) {
            allIds.append(habit.id)
            HabitDataManager.shared.saveAllHabitIds(allIds)
        }

        HabitDataManager.shared.updateWidgetTimeline()
    }
}

#Preview {
    ContentView()
}

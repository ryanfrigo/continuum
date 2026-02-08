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

    // Celebration state
    @State private var celebrationMilestone: StreakMilestone? = nil
    @State private var celebrationHabitName: String = ""
    @State private var healthMilestonePercentage: Int? = nil
    @State private var healthMilestoneHabitName: String = ""

    // Track previous streaks/health to detect milestone crossings
    @State private var previousStreaks: [UUID: Int] = [:]
    @State private var previousHealth: [UUID: Int] = [:]

    @AppStorage("hasCompletedOnboarding") private var onboardingCompleted = false

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
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(isPresented: $showingOnboarding) { selectedHabits in
                onboardingCompleted = true
                createSelectedHabits(selectedHabits)
            }
        }
        .onAppear {
            if !onboardingCompleted {
                showingOnboarding = true
            }
            initializeHabitOrders()
            initializeMilestoneTracking()
            refreshTrigger.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshTrigger.toggle()
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
        .scrollDisabled(habits.count <= 6) // Disable scrolling when 6 or fewer habits (fits on screen)
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

                Text(dateString)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer()

            // Overall health indicator
            if !habits.isEmpty {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Int(overallHealth * 100))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(healthColor(for: overallHealth))

                    Text("health")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
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

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private func healthColor(for health: Double) -> Color {
        let hue = 0.08 + health * 0.4 // Orange to cyan
        return Color(hue: hue, saturation: 0.8, brightness: 0.95)
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
        case .setStreak(let n):
            habit.setCurrentStreak(n)
        case .rename(let newName):
            habit.name = newName
        case .delete:
            modelContext.delete(habit)
            try? modelContext.save()
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

        guard wasJustCompleted else {
            previousStreaks[habit.id] = habit.currentStreak()
            previousHealth[habit.id] = Int(habit.habitHealth() * 100)
            return
        }

        let newStreak = habit.currentStreak()
        if let milestone = StreakMilestone.milestone(for: newStreak), newStreak > previousStreak {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                celebrationHabitName = habit.name
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    celebrationMilestone = milestone
                }
            }
        }

        let newHealth = Int(habit.habitHealth() * 100)
        let healthMilestones = [25, 50, 75, 100]
        for milestone in healthMilestones {
            if newHealth >= milestone && previousHealthValue < milestone {
                let delay = celebrationMilestone != nil ? 2.0 : 1.0
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
}

#Preview {
    ContentView()
}

import SwiftUI
import SwiftData

struct HabitCardView: View {
    @Bindable var habit: Habit
    var refreshTrigger: Bool = false
    var onAction: ((HabitAction) -> Void)? = nil

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

    private func streakColor(for streak: Int) -> Color {
        // Palette tuned to harmonize with iOS orange
        // Phase 1: Orange (38°) → Balanced Green (130°)
        // Phase 2: Balanced Green (130°) → Dark Blue (220°) with brightness falloff
        let hueOrange: Double = 38.0 / 360.0
        let hueGreen: Double = 130.0 / 360.0
        let hueBlueDark: Double = 220.0 / 360.0

        // Keep saturation close to orange; reduce brightness slightly toward dark blue
        let satStart: Double = 0.94
        let briStart: Double = 0.98
        let satGreen: Double = 0.85
        let briGreen: Double = 0.95
        let satBlue: Double = 0.90
        let briBlue: Double = 0.60 // dark target

        if streak <= habitFormationDays {
            let t = max(0, min(1, Double(streak) / Double(habitFormationDays)))
            let hue = hueOrange + (hueGreen - hueOrange) * t
            let sat = satStart + (satGreen - satStart) * t
            let bri = briStart + (briGreen - briStart) * t
            return Color(hue: hue, saturation: sat, brightness: bri)
        } else {
            let capped = min(streak, 1000)
            let t = max(0, min(1, Double(capped - habitFormationDays) / Double(1000 - habitFormationDays)))
            let hue = hueGreen + (hueBlueDark - hueGreen) * t
            let sat = satGreen + (satBlue - satGreen) * t
            let bri = briGreen + (briBlue - briGreen) * t
            return Color(hue: hue, saturation: sat, brightness: bri)
        }
    }
    
    private func triggerCompletionAnimation() {
        // Animation removed - card size remains constant
        wasCompletedToday = habit.isCompletedToday
    }

    var body: some View {
        let displayStreak: Int = getDisplayStreak()
        let isCompletedToday = habit.isCompletedToday
        let _ = lastRefreshDate // Force refresh when this changes
        
        // Border color: orange until today is completed, then based on streak
        let borderColor: Color = {
            if isCompletedToday {
                return streakColor(for: displayStreak)
            } else {
                return .orange // Orange until today is completed
            }
        }()

        ZStack {
            // Card content - no scale effect applied here
            VStack(alignment: .leading, spacing: 8) {
                // Header
                Text(habit.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(getStreakText())
                    .font(.caption.monospaced())
                    .foregroundStyle(.gray)
                    .padding(.bottom, 0)
                    .animation(nil, value: getStreakText())

                // History grid (66 days → 6 rows × 11 columns)
                let flags: [Bool] = habit.historyCompletionFlags(daysBack: habitFormationDays)
                
                // Ensure we always have exactly 66 items
                let paddedFlags: [Bool] = {
                    var result = flags
                    while result.count < habitFormationDays {
                        result.append(false)
                    }
                    return Array(result.prefix(habitFormationDays))
                }()
                
                GeometryReader { geo in
                    let totalWidth: CGFloat = geo.size.width
                    let availableWidth = totalWidth - CGFloat(columnsCount - 1) * dotSpacing
                    let dotSize: CGFloat = floor(availableWidth / CGFloat(columnsCount))
                    let columns: [GridItem] = Array(repeating: GridItem(.fixed(dotSize), spacing: dotSpacing), count: columnsCount)
                    // Always 6 rows for 66 days (6 × 11 = 66)
                    let rowsCount: Int = 6
                    let rows: CGFloat = CGFloat(rowsCount)
                    let gridHeight: CGFloat = dotSize * rows + dotSpacing * (rows - 1)

                    LazyVGrid(columns: columns, alignment: .leading, spacing: dotSpacing) {
                        // Always show exactly 66 squares
                        ForEach(0..<habitFormationDays, id: \.self) { idx in
                            let filled: Bool = paddedFlags[idx]
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
                .frame(height: 80) // Fixed height to ensure 6 rows are always visible
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
            NavigationStack {
                VStack(spacing: 30) {
                    Text("Change Streak")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    // Large display of current value
                    Text("\(selectedStreak)")
                        .font(.system(size: 72, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .animation(.easeInOut(duration: 0.2), value: selectedStreak)

                    // Stepper controls
                    HStack(spacing: 40) {
                        // Decrease button
                        Button(action: {
                            if selectedStreak > 0 {
                                selectedStreak -= 1
                                // Haptic feedback
                                #if os(iOS)
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                #endif
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(selectedStreak > 0 ? .orange : .gray)
                        }
                        .disabled(selectedStreak <= 0)

                        // Increase button
                        Button(action: {
                            if selectedStreak < 10000 {
                                selectedStreak += 1
                                // Haptic feedback
                                #if os(iOS)
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                #endif
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(selectedStreak < 10000 ? .orange : .gray)
                        }
                        .disabled(selectedStreak >= 10000)
                    }


                    Spacer()
                }
                .padding()
                .background(Color.black.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingSetStreak = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onAction?(.setStreak(selectedStreak))
                            showingSetStreak = false
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
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







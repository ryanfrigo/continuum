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
    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .reverse)]) private var habits: [Habit]

    @State private var showingAdd = false
    @State private var newHabitName: String = ""
    @State private var showingWelcome = false
    @State private var refreshTrigger = false
    
    private var hasHabits: Bool {
        let isEmpty = habits.isEmpty
        print("DEBUG: habits.count = \(habits.count), isEmpty = \(isEmpty)")
        return !isEmpty
    }
#if canImport(Inject)
    @ObserveInjection var inject
#endif

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init() {}

    var body: some View {
        NavigationStack {
            if !hasHabits {
                // Welcome screen for first-time users
                GeometryReader { geometry in
                    VStack(spacing: 60) {
                        Spacer()
                        
                        // App title
                        Text("Welcome to Continuum")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        // Get started button
                        Button {
                            newHabitName = ""
                            showingAdd = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Track a Habit")
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.orange)
                            )
                        }
                        
                        Spacer()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color.black.ignoresSafeArea())
                    .overlay(
                        RoundedRectangle(cornerRadius: 60)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hue: 38.0/360.0, saturation: 0.94, brightness: 0.98),   // Orange
                                        Color(hue: 130.0/360.0, saturation: 0.85, brightness: 0.95), // Green
                                        Color(hue: 220.0/360.0, saturation: 0.90, brightness: 0.60)  // Dark Blue
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 20
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .ignoresSafeArea()
                    )
                }
                .ignoresSafeArea()
            } else {
                // Normal habit grid view
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(habits) { habit in
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
                            }
                        }
                    }
                    .padding(12)
                }
                .background(Color.black.ignoresSafeArea())
                .toolbar {
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
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddHabitSheet(newHabitName: $newHabitName) { name in
                let habit = Habit(name: name)
                modelContext.insert(habit)
                showingAdd = false
            } onCancel: {
                showingAdd = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
        }
        .onAppear {
            // Initial refresh when the view appears
            refreshTrigger.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Trigger a refresh when the app becomes active to update day/streak display
            refreshTrigger.toggle()
        }
    }
}

#Preview {
    ContentView()
}

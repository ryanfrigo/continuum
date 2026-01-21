import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]

    @State private var isEditMode = false
    @State private var showingResetConfirmation = false
    @State private var showingAbout = false
    @State private var notificationPermissionGranted = false
    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Notifications Section
                Section {
                    ForEach(sortedHabits) { habit in
                        HabitNotificationRow(
                            habit: habit,
                            notificationPermissionGranted: notificationPermissionGranted,
                            onRequestPermission: { requestNotificationPermission() },
                            onSave: { saveAndSchedule(habit) }
                        )
                        .listRowBackground(Color(red: 0.1, green: 0.1, blue: 0.11))
                    }
                } header: {
                    Text("Daily Reminders")
                        .foregroundStyle(.gray)
                } footer: {
                    Text("Set a daily reminder time for each habit. You'll receive a notification if you haven't completed it yet.")
                        .foregroundStyle(.gray.opacity(0.7))
                }

                // Reorder Habits Section
                Section {
                    ForEach(sortedHabits) { habit in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.gray)
                            Text(habit.name)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(habit.currentStreak()) days")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        .listRowBackground(Color(red: 0.1, green: 0.1, blue: 0.11))
                    }
                    .onMove(perform: moveHabit)
                } header: {
                    Text("Reorder Habits")
                        .foregroundStyle(.gray)
                } footer: {
                    Text("Drag to reorder your habits on the home screen")
                        .foregroundStyle(.gray.opacity(0.7))
                }

                // App Info Section
                Section {
                    Button {
                        showingAbout = true
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.orange)
                            Text("About Continuum")
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    .listRowBackground(Color(red: 0.1, green: 0.1, blue: 0.11))

                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.orange)
                        Text("Version")
                            .foregroundStyle(.white)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.gray)
                    }
                    .listRowBackground(Color(red: 0.1, green: 0.1, blue: 0.11))
                } header: {
                    Text("App")
                        .foregroundStyle(.gray)
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete All Habits")
                        }
                        .foregroundStyle(.red)
                    }
                    .listRowBackground(Color(red: 0.1, green: 0.1, blue: 0.11))
                } header: {
                    Text("Danger Zone")
                        .foregroundStyle(.gray)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.orange)
                }
            }
            .onAppear {
                checkNotificationPermission()
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("Delete All Habits?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                deleteAllHabits()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all your habits and their history. This cannot be undone.")
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .alert("Notifications Disabled", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications in Settings to receive habit reminders.")
        }
    }

    private var sortedHabits: [Habit] {
        habits.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }

    private func moveHabit(from source: IndexSet, to destination: Int) {
        var reorderedHabits = sortedHabits
        reorderedHabits.move(fromOffsets: source, toOffset: destination)

        for (index, habit) in reorderedHabits.enumerated() {
            habit.order = index
        }

        try? modelContext.save()
    }

    private func deleteAllHabits() {
        NotificationManager.shared.removeAllNotifications()
        for habit in habits {
            modelContext.delete(habit)
        }
        try? modelContext.save()
        dismiss()
    }

    private func checkNotificationPermission() {
        Task {
            let status = await NotificationManager.shared.checkPermissionStatus()
            await MainActor.run {
                notificationPermissionGranted = (status == .authorized)
            }
        }
    }

    private func requestNotificationPermission() {
        Task {
            let granted = await NotificationManager.shared.requestPermission()
            await MainActor.run {
                notificationPermissionGranted = granted
                if !granted {
                    showingPermissionAlert = true
                }
            }
        }
    }

    private func saveAndSchedule(_ habit: Habit) {
        try? modelContext.save()
        NotificationManager.shared.scheduleNotification(for: habit)
    }
}

// MARK: - Habit Notification Row

struct HabitNotificationRow: View {
    @Bindable var habit: Habit
    let notificationPermissionGranted: Bool
    let onRequestPermission: () -> Void
    let onSave: () -> Void

    @State private var showTimePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Habit name and toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    if habit.reminderEnabled {
                        Text(formattedTime)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { habit.reminderEnabled },
                    set: { newValue in
                        if newValue && !notificationPermissionGranted {
                            onRequestPermission()
                        } else {
                            habit.reminderEnabled = newValue
                            onSave()
                        }
                    }
                ))
                .tint(.orange)
                .labelsHidden()
            }

            // Time picker (shown when enabled)
            if habit.reminderEnabled {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)

                    Text("Remind at")
                        .font(.subheadline)
                        .foregroundStyle(.gray)

                    Spacer()

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { habit.reminderTime },
                            set: { newValue in
                                habit.reminderTime = newValue
                                onSave()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(.orange)
                    .colorScheme(.dark)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: habit.reminderTime)
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // App Icon
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "infinity")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.black)
                        )
                        .shadow(color: .orange.opacity(0.3), radius: 20)

                    VStack(spacing: 8) {
                        Text("Continuum")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)

                        Text("Build better habits, one day at a time")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }

                    // Info Cards
                    VStack(spacing: 16) {
                        AboutCard(
                            icon: "flame.fill",
                            title: "66 Day Science",
                            description: "Research shows it takes an average of 66 days to form a new habit. Continuum visualizes your progress toward this goal."
                        )

                        AboutCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Health Score",
                            description: "Your habit health shows what percentage of the last 66 days you've completed. Watch it grow as you stay consistent."
                        )

                        AboutCard(
                            icon: "sparkles",
                            title: "Milestones",
                            description: "Celebrate your achievements at 7, 21, 66, and 100 day streaks. Each milestone brings you closer to lasting change."
                        )
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)

                    Text("Made with ♥ by Orion Labs")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .padding(.top, 40)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct AboutCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.11))
        )
    }
}

#Preview {
    SettingsView()
}

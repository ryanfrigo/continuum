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
                // Preferences Section
                Section {
                    Toggle(isOn: Binding(
                        get: { SoundManager.soundEnabled },
                        set: { SoundManager.soundEnabled = $0 }
                    )) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.orange)
                            Text("Sound Effects")
                                .foregroundStyle(.white)
                        }
                    }
                    .tint(.orange)
                    .listRowBackground(Color(red: 0.1, green: 0.1, blue: 0.11))

                    Toggle(isOn: Binding(
                        get: { SoundManager.hapticsEnabled },
                        set: { SoundManager.hapticsEnabled = $0 }
                    )) {
                        HStack {
                            Image(systemName: "hand.tap.fill")
                                .foregroundStyle(.orange)
                            Text("Haptic Feedback")
                                .foregroundStyle(.white)
                        }
                    }
                    .tint(.orange)
                    .listRowBackground(Color(red: 0.1, green: 0.1, blue: 0.11))
                } header: {
                    Text("Preferences")
                        .foregroundStyle(.gray)
                }

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
                        UserDefaults.standard.set(false, forKey: "hasCompletedWalkthrough")
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.orange)
                            Text("Show Walkthrough")
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    .listRowBackground(Color(red: 0.1, green: 0.1, blue: 0.11))

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
                        Image(systemName: "diamond.fill")
                            .foregroundStyle(.orange)
                        Text("VERSION")
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.white)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0")
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.orange)
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
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
        // Clean up widget data
        HabitDataManager.shared.saveAllHabitIds([])
        HabitDataManager.shared.updateWidgetTimeline()
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
    @State private var ringRotation: Double = 0
    @State private var glowPulse: Double = 0.3

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // Subtle grid background
                GridPattern()
                    .opacity(0.03)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Geometric Logo
                        ZStack {
                            // Outer rotating ring
                            Circle()
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                .frame(width: 140, height: 140)

                            // Dashed rotating ring
                            Circle()
                                .stroke(Color.orange.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(ringRotation))

                            // Inner ring with glow
                            Circle()
                                .stroke(Color.orange, lineWidth: 2)
                                .frame(width: 90, height: 90)
                                .shadow(color: .orange.opacity(glowPulse), radius: 15)

                            // Center icon
                            Image(systemName: "infinity")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(.orange)

                            // Corner brackets
                            ForEach(0..<4, id: \.self) { i in
                                CornerBracket()
                                    .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                                    .frame(width: 16, height: 16)
                                    .rotationEffect(.degrees(Double(i) * 90))
                                    .offset(
                                        x: (i == 0 || i == 3) ? -60 : 60,
                                        y: (i == 0 || i == 1) ? -60 : 60
                                    )
                            }
                        }
                        .padding(.top, 30)

                        VStack(spacing: 12) {
                            Text("CONTINUUM")
                                .font(.title2.weight(.black).monospaced())
                                .foregroundStyle(.white)
                                .tracking(6)

                            Text("HABIT FORMATION SYSTEM")
                                .font(.caption.monospaced())
                                .foregroundStyle(.orange)
                                .tracking(2)

                            Rectangle()
                                .fill(Color.orange.opacity(0.3))
                                .frame(width: 60, height: 1)
                                .padding(.vertical, 4)

                            Text("VERSION 3.0")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.gray)
                                .tracking(2)
                        }

                        // Info Cards
                        VStack(spacing: 16) {
                            AboutCard(
                                icon: "waveform.path.ecg",
                                code: "SYS.PROTOCOL.066",
                                title: "66 DAY PROTOCOL",
                                description: "Neural pathway research indicates 66 days to encode permanent behavioral patterns. System monitors progression toward permanence."
                            )

                            AboutCard(
                                icon: "chart.line.uptrend.xyaxis",
                                code: "SYS.INTEGRITY.IDX",
                                title: "INTEGRITY INDEX",
                                description: "Real-time calculation of your 66-day completion percentage. Optimal performance achieved at maximum integrity."
                            )

                            AboutCard(
                                icon: "diamond.fill",
                                code: "SYS.MILESTONE.TRK",
                                title: "MILESTONE EVENTS",
                                description: "System triggers at 7, 21, 66, and 100 day thresholds. Each milestone signifies deeper neural encoding."
                            )
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 40)

                        VStack(spacing: 4) {
                            Text("DEVELOPED BY")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.gray.opacity(0.5))
                                .tracking(2)
                            Text("ORION LABS")
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(.gray)
                                .tracking(3)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") {
                        dismiss()
                    }
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowPulse = 0.8
            }
        }
    }
}

struct AboutCard: View {
    let icon: String
    let code: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.orange)

                Spacer()

                Text(code)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.orange.opacity(0.6))
            }

            Text(title)
                .font(.subheadline.weight(.bold).monospaced())
                .foregroundStyle(.white)
                .tracking(1)

            Text(description)
                .font(.caption)
                .foregroundStyle(.gray)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    SettingsView()
}

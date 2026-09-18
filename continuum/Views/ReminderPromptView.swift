import SwiftUI
import UserNotifications

/// When to ask about reminders. Pure so the "never nag twice" rules are tested.
///
/// Reminders are the only thing that brings someone back tomorrow, but the app
/// used to never mention them — you had to find the per-habit toggle in
/// Settings. This asks once, after the first completion, when the app has just
/// proved it does something.
enum ReminderPrompt {
    /// Default reminder time. Stays clear of the 8pm streak-at-risk alert so a
    /// habit never pings twice in one evening.
    static let defaultHour = 9
    static let defaultMinute = 0

    static func shouldAsk(
        alreadyAsked: Bool,
        permission: UNAuthorizationStatus,
        anyReminderEnabled: Bool,
        totalCompletions: Int
    ) -> Bool {
        guard !alreadyAsked else { return false }
        // Asking after a denial or a grant is pointless — iOS only prompts once.
        guard permission == .notDetermined else { return false }
        guard !anyReminderEnabled else { return false }
        return totalCompletions == 1
    }
}

struct ReminderPromptView: View {
    var accent: Color = .orange
    let onEnable: (Date) -> Void
    let onDismiss: () -> Void

    @State private var time: Date = {
        var components = DateComponents()
        components.hour = ReminderPrompt.defaultHour
        components.minute = ReminderPrompt.defaultMinute
        return Calendar.current.date(from: components) ?? Date()
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 18) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(accent)

                VStack(spacing: 6) {
                    Text("ONE NUDGE A DAY")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(accent)

                    Text("Only if it isn't done yet.\nChange it anytime in Settings.")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .colorScheme(.dark)
                    .frame(height: 96)
                    .clipped()

                VStack(spacing: 10) {
                    Button {
                        SoundManager.shared.triggerSelectionHaptic()
                        onEnable(time)
                    } label: {
                        Text("REMIND ME")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(accent))
                    }

                    Button {
                        SoundManager.shared.triggerSelectionHaptic()
                        onDismiss()
                    } label: {
                        Text("Not now")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.vertical, 6)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.07, green: 0.07, blue: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(accent.opacity(0.5), lineWidth: 1.5)
            )
            .shadow(color: accent.opacity(0.25), radius: 24)
            .padding(.horizontal, 36)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Set a daily reminder. You'll only be notified if the habit isn't done yet.")
    }
}

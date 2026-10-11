import SwiftUI

/// One text box that goes straight to Ryan. Used from Settings ("settings")
/// and by the one-time check-in two weeks in ("checkin").
struct FeedbackSheet: View {
    enum Kind: String {
        case settings, checkin

        var title: String {
            self == .checkin ? "Quick question" : "Send Feedback"
        }

        var prompt: String {
            self == .checkin
                ? "How's Continuum working for you? What would you change?"
                : "Something broken, missing or annoying? Tell me."
        }
    }

    let kind: Kind
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var sending = false
    @State private var sent = false
    @State private var failed = false
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !sending && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()

                if sent {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(HabitPalette.accent)
                        Text("Thank you")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text("I read every one of these.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(kind.prompt)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)

                        TextEditor(text: $text)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .tint(HabitPalette.accent)
                            .scrollContentBackground(.hidden)
                            .focused($focused)
                            .padding(12)
                            .frame(minHeight: 160, maxHeight: 260)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focused ? HabitPalette.accent.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                            )

                        Text(failed
                             ? "Couldn't send. Check your connection and try again."
                             : "Anonymous. Add your email if you'd like a reply.")
                            .font(.system(size: 13))
                            .foregroundStyle(failed ? Color.red.opacity(0.8) : Color.white.opacity(0.4))

                        Button(action: send) {
                            Text(sending ? "Sending…" : "Send")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(canSend ? .black : Color.white.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(canSend ? HabitPalette.accent : Color.white.opacity(0.08))
                                )
                        }
                        .disabled(!canSend)

                        Spacer()
                    }
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(kind.title.uppercased())
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(2)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "DONE" : "CLOSE") { dismiss() }
                        .font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(HabitPalette.accent)
                }
            }
            .onAppear { focused = true }
        }
        .preferredColorScheme(.dark)
    }

    private func send() {
        sending = true
        failed = false
        Task {
            let ok = await UsageReporter.sendFeedback(kind: kind.rawValue, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
            sending = false
            if ok {
                focused = false
                withAnimation(.easeOut(duration: 0.25)) { sent = true }
            } else {
                failed = true
            }
        }
    }
}

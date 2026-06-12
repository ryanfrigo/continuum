import SwiftUI

struct WalkthroughOverlay: View {
    let onDismiss: () -> Void

    @State private var currentStep = 0
    @State private var contentOpacity: Double = 0
    @State private var backgroundOpacity: Double = 0

    private let steps: [WalkthroughStep] = [
        WalkthroughStep(
            icon: "hand.tap.fill",
            title: "Double-Tap to Complete",
            description: "Double-tap a habit card to mark it done. Watch the progress bar fill and celebrate your win."
        ),
        WalkthroughStep(
            icon: "arrow.uturn.backward",
            title: "Tap to Undo",
            description: "Made a mistake? Tap a completed habit and confirm to undo it."
        ),
        WalkthroughStep(
            icon: "hand.draw.fill",
            title: "Long Press for Options",
            description: "Long press any card to edit, share, delete, or manage your habit."
        ),
        WalkthroughStep(
            icon: "snowflake",
            title: "Streak Freezes",
            description: "Miss a day? Streak freezes protect your progress. You earn them at 7, 21, and 100-day milestones."
        ),
        WalkthroughStep(
            icon: "star.fill",
            title: "66-Day Goal",
            description: "Science shows 66 days forms a lasting habit. Hit that mark and your habit graduates — permanently formed."
        ),
    ]

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(backgroundOpacity * 0.85)
                .ignoresSafeArea()
                .onTapGesture { advanceStep() }

            // Step content
            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 100, height: 100)

                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.orange)
                }

                // Text
                VStack(spacing: 14) {
                    Text(steps[currentStep].title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text(steps[currentStep].description)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Progress dots + button
                VStack(spacing: 24) {
                    // Step indicators
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentStep ? Color.orange : Color.white.opacity(0.2))
                                .frame(width: i == currentStep ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                        }
                    }

                    // Action button
                    Button {
                        SoundManager.shared.triggerSelectionHaptic()
                        advanceStep()
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentStep < steps.count - 1 ? "Next" : "Get Started")
                                .font(.system(size: 17, weight: .semibold))
                            if currentStep < steps.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.orange)
                        )
                    }
                    .padding(.horizontal, 24)

                    // Skip
                    if currentStep < steps.count - 1 {
                        Button {
                            dismiss()
                        } label: {
                            Text("Skip")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                }
                .padding(.bottom, 50)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                backgroundOpacity = 1
                contentOpacity = 1
            }
        }
    }

    private func advanceStep() {
        if currentStep < steps.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                contentOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                currentStep += 1
                withAnimation(.easeInOut(duration: 0.25)) {
                    contentOpacity = 1
                }
            }
        } else {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 0
            contentOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Step Data

private struct WalkthroughStep {
    let icon: String
    let title: String
    let description: String
}

// MARK: - Preview

#Preview {
    WalkthroughOverlay(onDismiss: {})
}

import SwiftUI

// MARK: - Milestone Definitions

enum StreakMilestone: Int, CaseIterable {
    // Dense rewards early (days 1–7 decide retention), scarce later.
    case dayOne = 1
    case dayThree = 3
    case dayFive = 5
    case week = 7
    case threeWeeks = 21
    case habitFormed = 66
    case hundred = 100
    case year = 365

    var title: String {
        switch self {
        case .dayOne: return "1"
        case .dayThree: return "3"
        case .dayFive: return "5"
        case .week: return "7"
        case .threeWeeks: return "21"
        case .habitFormed: return "66"
        case .hundred: return "100"
        case .year: return "365"
        }
    }

    var subtitle: String {
        switch self {
        case .dayOne: return "day"
        default: return "days"
        }
    }

    var message: String {
        switch self {
        case .dayOne: return "The first mark is on the grid"
        case .dayThree: return "Three days. It's becoming real"
        case .dayFive: return "Five days. Momentum is yours"
        case .week: return "One week. You're someone who shows up"
        case .threeWeeks: return "21 days. This is becoming you"
        case .habitFormed: return "Habit formed"
        case .hundred: return "100 days. Few people get here"
        case .year: return "One year. This is who you are"
        }
    }

    /// Early milestones get a lighter celebration (no full takeover fatigue).
    var isMinor: Bool {
        switch self {
        case .dayOne, .dayThree, .dayFive: return true
        default: return false
        }
    }

    static func milestone(for streak: Int) -> StreakMilestone? {
        return StreakMilestone(rawValue: streak)
    }
}

// MARK: - Shared Celebration Design System
//
// Every celebration is the SAME card: dark fill, 1px accent border with a
// soft glow, identical typography scale and spacing. Only the accent color
// and content change. The accent follows the habit's progress color
// (orange → green → cyan) for habit moments; gold and ice are reserved for
// graduation/perfect/record and freeze moments.

enum CelebrationVisual {
    case value(String, unit: String)   // big number + unit ("7" / "DAYS")
    case icon(String)                  // SF symbol in a thin ring
    case sevenDots                     // perfect week row
}

enum CelebrationSound {
    case standard, rare
}

struct CelebrationCard: View {
    let accent: Color
    let visual: CelebrationVisual
    var title: String? = nil           // "PERFECT DAY" — tracked, accent
    var message: String? = nil         // sentence, white 60%
    var subject: String? = nil         // habit name, white 38%
    var meta: String? = nil            // "2 LEFT" / "3 WEEKS IN A ROW"
    var sound: CelebrationSound = .standard
    var autoDismissAfter: Double? = nil
    var primaryAction: (label: String, icon: String?, action: () -> Void)? = nil
    var secondaryActionLabel: String? = nil   // uses onDismiss
    let onDismiss: () -> Void

    // Animation states
    @State private var backgroundOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.93
    @State private var cardOpacity: Double = 0
    @State private var visualScale: CGFloat = 0.4
    @State private var visualOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var dotScales: [CGFloat] = Array(repeating: 0, count: 7)

    private var hasButtons: Bool { primaryAction != nil || secondaryActionLabel != nil }

    var body: some View {
        ZStack {
            // Dim layer
            Color(red: 0.04, green: 0.05, blue: 0.07).opacity(backgroundOpacity * 0.94)
                .ignoresSafeArea()
                .onTapGesture { if !hasButtons { onDismiss() } }

            VStack(spacing: 22) {
                // ── The card ──
                VStack(spacing: 18) {
                    visualView
                        .scaleEffect(visualScale)
                        .opacity(visualOpacity)
                        .padding(.top, 6)

                    // 1px accent divider
                    Rectangle()
                        .fill(accent.opacity(0.25))
                        .frame(width: 44, height: 1)
                        .opacity(textOpacity)

                    VStack(spacing: 10) {
                        if let title {
                            Text(title)
                                .font(.system(size: 21, weight: .black, design: .rounded))
                                .foregroundStyle(accent)
                                .tracking(3)
                                .multilineTextAlignment(.center)
                        }

                        if let message {
                            Text(message)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }

                        if let subject {
                            Text(subject)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.38))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }

                        if let meta {
                            Text(meta.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(accent.opacity(0.75))
                                .tracking(1.5)
                                .padding(.top, 2)
                        }
                    }
                    .opacity(textOpacity)

                    if hasButtons {
                        VStack(spacing: 10) {
                            if let primary = primaryAction {
                                Button(action: primary.action) {
                                    HStack(spacing: 8) {
                                        if let icon = primary.icon {
                                            Image(systemName: icon)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        Text(primary.label)
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(accent))
                                }
                            }
                            if let secondary = secondaryActionLabel {
                                Button(action: onDismiss) {
                                    Text(secondary)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.6))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.top, 4)
                        .opacity(textOpacity)
                    }
                }
                .padding(28)
                .frame(maxWidth: 330)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.07, green: 0.08, blue: 0.10))
                )
                .overlay(
                    // The signature 1px accent border
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accent.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: accent.opacity(0.22), radius: 28, y: 4)
                .scaleEffect(cardScale)
                .opacity(cardOpacity)

                // Dismiss hint (only for tap-anywhere cards)
                if !hasButtons {
                    Text("TAP TO CONTINUE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .tracking(2)
                        .opacity(textOpacity)
                }
            }
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .contain)
        .onAppear { start() }
    }

    // MARK: Visual zone

    @ViewBuilder
    private var visualView: some View {
        switch visual {
        case .value(let value, let unit):
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, accent.opacity(0.85)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Text(unit.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
                    .tracking(5)
            }

        case .icon(let symbol):
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.3), lineWidth: 1)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(accent.opacity(0.10))
                    .frame(width: 76, height: 76)
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.5), radius: 8)
            }

        case .sevenDots:
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accent)
                        .frame(width: 18, height: 18)
                        .shadow(color: accent.opacity(0.5), radius: 4)
                        .scaleEffect(dotScales[i])
                }
            }
            .padding(.vertical, 14)
        }
    }

    // MARK: Animation + feedback

    private func start() {
        switch sound {
        case .standard: SoundManager.shared.playCelebrationSound()
        case .rare: SoundManager.shared.playRareCompletionSound()
        }
        SoundManager.shared.triggerCelebrationHaptic()

        withAnimation(.easeOut(duration: 0.25)) { backgroundOpacity = 1 }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8).delay(0.08)) {
            cardScale = 1.0
            cardOpacity = 1.0
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.28)) {
            visualScale = 1.0
            visualOpacity = 1.0
        }
        if case .sevenDots = visual {
            for i in 0..<7 {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55).delay(0.32 + Double(i) * 0.06)) {
                    dotScales[i] = 1.0
                }
            }
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.45)) { textOpacity = 1.0 }

        if let delay = autoDismissAfter {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { onDismiss() }
        }
    }
}

// MARK: - Shared accent palette

enum CelebrationPalette {
    static let gold = Color(hue: 0.12, saturation: 0.8, brightness: 0.95)
    static let ice = Color(hue: 0.52, saturation: 0.55, brightness: 0.95)
}

// MARK: - Streak Milestone Overlay

struct CelebrationOverlay: View {
    let milestone: StreakMilestone
    let habitName: String
    var accent: Color = .orange   // habit's current progress color
    let onDismiss: () -> Void

    var body: some View {
        CelebrationCard(
            accent: accent,
            visual: .value(milestone.title, unit: milestone.subtitle),
            message: milestone.message,
            subject: habitName,
            autoDismissAfter: milestone.isMinor ? 2.4 : nil,
            onDismiss: onDismiss
        )
        .accessibilityLabel("\(milestone.title) \(milestone.subtitle) milestone for \(habitName). \(milestone.message).")
    }
}

// MARK: - Health Milestone Overlay

struct HealthMilestoneOverlay: View {
    let percentage: Int
    let habitName: String
    var accent: Color = .orange   // habit's current progress color
    let onDismiss: () -> Void

    private var healthMessage: String {
        switch percentage {
        case 25: return "Quarter of the way to optimal"
        case 50: return "Halfway there. Keep it boring"
        case 75: return "Almost optimal"
        case 100: return "Perfect health. Machine mode"
        default: return "Progress achieved"
        }
    }

    var body: some View {
        CelebrationCard(
            accent: accent,
            visual: .value("\(percentage)", unit: "%"),
            title: "HEALTH",
            message: healthMessage,
            subject: habitName,
            onDismiss: onDismiss
        )
        .accessibilityLabel("\(percentage) percent health for \(habitName).")
    }
}

// MARK: - Habit Graduation Overlay

struct HabitGraduationOverlay: View {
    let habitName: String
    let onDismiss: () -> Void
    let onShare: () -> Void

    var body: some View {
        CelebrationCard(
            accent: CelebrationPalette.gold,
            visual: .value("66", unit: "days"),
            title: "HABIT FORMED",
            message: "This isn't something you do anymore.\nIt's who you are.",
            subject: habitName,
            primaryAction: ("Share Achievement", "square.and.arrow.up", onShare),
            secondaryActionLabel: "Continue",
            onDismiss: onDismiss
        )
        .accessibilityLabel("Habit graduation. \(habitName) has been formed after 66 days.")
    }
}

// MARK: - Perfect Day Overlay

struct PerfectDayOverlay: View {
    let habitCount: Int
    let onDismiss: () -> Void

    var body: some View {
        CelebrationCard(
            accent: CelebrationPalette.gold,
            visual: .icon("checkmark"),
            title: "PERFECT DAY",
            message: habitCount == 1 ? "Habit complete" : "All \(habitCount) habits complete",
            autoDismissAfter: 2.4,
            onDismiss: onDismiss
        )
        .accessibilityLabel("Perfect day. All \(habitCount) habits completed.")
    }
}

// MARK: - Perfect Week Overlay

struct PerfectWeekOverlay: View {
    let habitCount: Int
    let weekCount: Int   // consecutive perfect weeks (1 = first)
    let onDismiss: () -> Void

    var body: some View {
        CelebrationCard(
            accent: CelebrationPalette.gold,
            visual: .sevenDots,
            title: "PERFECT WEEK",
            message: "7 days. Every habit. Flawless.",
            meta: weekCount > 1 ? "\(weekCount) weeks in a row" : nil,
            sound: .rare,
            onDismiss: onDismiss
        )
        .accessibilityLabel("Perfect week. All \(habitCount) habits completed every day for 7 days.")
    }
}

// MARK: - Streak Saved (Freeze) Overlay

struct FreezeSaveOverlay: View {
    let habitName: String
    let streak: Int
    let freezesLeft: Int
    let onDismiss: () -> Void

    var body: some View {
        CelebrationCard(
            accent: CelebrationPalette.ice,
            visual: .icon("snowflake"),
            title: "STREAK SAVED",
            message: "A freeze protected your \(streak)-day streak",
            subject: habitName,
            meta: freezesLeft > 0 ? "\(freezesLeft) freeze\(freezesLeft == 1 ? "" : "s") left" : nil,
            onDismiss: onDismiss
        )
        .accessibilityLabel("Streak saved. A freeze protected your \(streak)-day streak for \(habitName).")
    }
}

// MARK: - Personal Record Overlay

struct RecordOverlay: View {
    let habitName: String
    let streak: Int
    var accent: Color = CelebrationPalette.gold
    let onDismiss: () -> Void

    var body: some View {
        CelebrationCard(
            accent: accent,
            visual: .value("\(streak)", unit: "days"),
            title: "PERSONAL RECORD",
            message: "Your longest streak ever",
            subject: habitName,
            sound: .rare,
            onDismiss: onDismiss
        )
        .accessibilityLabel("New personal record. \(streak)-day streak for \(habitName).")
    }
}

// MARK: - Supporting Shapes

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct GridPattern: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 30
            for x in stride(from: 0, to: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.orange.opacity(0.1)), lineWidth: 0.5)
            }
            for y in stride(from: 0, to: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.orange.opacity(0.1)), lineWidth: 0.5)
            }
        }
    }
}

struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 8))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + 8, y: rect.minY))
        return path
    }
}

// MARK: - Previews

#Preview("Day 7 Milestone") {
    CelebrationOverlay(milestone: .week, habitName: "Exercise", accent: .orange, onDismiss: {})
}

#Preview("Graduation") {
    HabitGraduationOverlay(habitName: "Exercise", onDismiss: {}, onShare: {})
}

#Preview("Perfect Day") {
    PerfectDayOverlay(habitCount: 5, onDismiss: {})
}

#Preview("Perfect Week") {
    PerfectWeekOverlay(habitCount: 4, weekCount: 2, onDismiss: {})
}

#Preview("Streak Saved") {
    FreezeSaveOverlay(habitName: "Meditate", streak: 23, freezesLeft: 2, onDismiss: {})
}

#Preview("Record") {
    RecordOverlay(habitName: "Run", streak: 31, onDismiss: {})
}

#Preview("Health") {
    HealthMilestoneOverlay(percentage: 50, habitName: "Read", onDismiss: {})
}

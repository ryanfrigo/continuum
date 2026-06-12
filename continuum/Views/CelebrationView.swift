import SwiftUI

// MARK: - Milestone Definitions

enum StreakMilestone: Int, CaseIterable {
    case week = 7
    case threeWeeks = 21
    case habitFormed = 66
    case hundred = 100
    case year = 365

    var title: String {
        switch self {
        case .week: return "7"
        case .threeWeeks: return "21"
        case .habitFormed: return "66"
        case .hundred: return "100"
        case .year: return "365"
        }
    }

    var subtitle: String {
        switch self {
        case .week: return "days"
        case .threeWeeks: return "days"
        case .habitFormed: return "days"
        case .hundred: return "days"
        case .year: return "days"
        }
    }

    var message: String {
        switch self {
        case .week: return "First week complete"
        case .threeWeeks: return "Three weeks strong"
        case .habitFormed: return "Habit formed"
        case .hundred: return "Century achieved"
        case .year: return "One year milestone"
        }
    }

    var accentColor: Color {
        switch self {
        case .week: return .orange
        case .threeWeeks: return Color(hue: 0.12, saturation: 0.8, brightness: 0.95)
        case .habitFormed: return Color(hue: 0.35, saturation: 0.7, brightness: 0.9)
        case .hundred: return Color(hue: 0.5, saturation: 0.7, brightness: 0.9)
        case .year: return Color(hue: 0.55, saturation: 0.6, brightness: 0.95)
        }
    }

    static func milestone(for streak: Int) -> StreakMilestone? {
        return StreakMilestone(rawValue: streak)
    }
}

// MARK: - Celebration Overlay

struct CelebrationOverlay: View {
    let milestone: StreakMilestone
    let habitName: String
    let onDismiss: () -> Void

    // Animation states
    @State private var backgroundOpacity: Double = 0
    @State private var ringScales: [CGFloat] = [0, 0, 0, 0]
    @State private var ringOpacities: [Double] = [0, 0, 0, 0]
    @State private var numberScale: CGFloat = 0
    @State private var numberOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Clean dark background
                Color(red: 0.06, green: 0.07, blue: 0.09).opacity(backgroundOpacity * 0.95)
                    .ignoresSafeArea()

                // Center content
                VStack(spacing: 24) {
                    Spacer()

                    // Clean animated rings
                    ZStack {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .stroke(
                                    Color.orange.opacity(0.4 - Double(index) * 0.08),
                                    lineWidth: 2 - CGFloat(index) * 0.3
                                )
                                .frame(width: 140 + CGFloat(index) * 40)
                                .scaleEffect(ringScales[index])
                                .opacity(ringOpacities[index])
                        }

                        // Main number
                        VStack(spacing: 4) {
                            Text(milestone.title)
                                .font(.system(size: 72, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text(milestone.subtitle)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.orange)
                                .textCase(.uppercase)
                                .tracking(4)
                        }
                        .scaleEffect(numberScale)
                        .opacity(numberOpacity)
                    }

                    // Message and habit name
                    VStack(spacing: 12) {
                        Text(milestone.message)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(habitName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .opacity(textOpacity)

                    Spacer()

                    // Dismiss hint
                    Text("Tap to continue")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .opacity(textOpacity)
                        .padding(.bottom, 60)
                }
            }
        }
        .onTapGesture { onDismiss() }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Play celebration sound and haptics
        SoundManager.shared.playCelebrationSound()
        SoundManager.shared.triggerCelebrationHaptic()

        // Phase 1: Background fade
        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 1
        }

        // Phase 2: Rings expand
        for i in 0..<4 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(i) * 0.08)) {
                ringScales[i] = 1.0
                ringOpacities[i] = 1.0
            }
        }

        // Phase 3: Number appears
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.25)) {
            numberScale = 1.0
            numberOpacity = 1.0
        }

        // Phase 4: Text fades in
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            textOpacity = 1.0
        }
    }
}

// MARK: - Health Milestone Overlay

struct HealthMilestoneOverlay: View {
    let percentage: Int
    let habitName: String
    let onDismiss: () -> Void

    @State private var backgroundOpacity: Double = 0
    @State private var ringProgress: CGFloat = 0
    @State private var numberScale: CGFloat = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            // Clean dark background
            Color(red: 0.06, green: 0.07, blue: 0.09).opacity(backgroundOpacity * 0.95)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Progress ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 10)
                        .frame(width: 160, height: 160)

                    // Progress ring - clean orange
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))

                    // Percentage
                    VStack(spacing: 4) {
                        Text("\(percentage)")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("%")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.orange)
                    }
                    .scaleEffect(numberScale)
                }

                // Message
                VStack(spacing: 12) {
                    Text(healthMessage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(habitName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .opacity(textOpacity)

                Spacer()

                Text("Tap to continue")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .opacity(textOpacity)
                    .padding(.bottom, 60)
            }
        }
        .onTapGesture { onDismiss() }
        .onAppear { startAnimation() }
    }

    private var healthMessage: String {
        switch percentage {
        case 25: return "Quarter progress"
        case 50: return "Halfway there"
        case 75: return "Almost optimal"
        case 100: return "Perfect health"
        default: return "Progress achieved"
        }
    }

    private func startAnimation() {
        SoundManager.shared.playCelebrationSound()
        SoundManager.shared.triggerCelebrationHaptic()

        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 1
        }

        withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
            ringProgress = CGFloat(percentage) / 100.0
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.3)) {
            numberScale = 1.0
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            textOpacity = 1.0
        }
    }
}

// MARK: - Habit Graduation Overlay

struct HabitGraduationOverlay: View {
    let habitName: String
    let onDismiss: () -> Void
    let onShare: () -> Void

    private let goldAccent = Color(hue: 0.12, saturation: 0.8, brightness: 0.95)

    // Animation states
    @State private var backgroundOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.01
    @State private var glowOpacity: Double = 0
    @State private var ringProgress: CGFloat = 0
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0
    @State private var numberScale: CGFloat = 0
    @State private var numberOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0

    var body: some View {
        ZStack {
            // Phase 1: Deep dark background
            Color(red: 0.04, green: 0.04, blue: 0.06).opacity(backgroundOpacity * 0.97)
                .ignoresSafeArea()

            // Golden radial glow from center
            RadialGradient(
                gradient: Gradient(colors: [
                    goldAccent.opacity(0.3),
                    goldAccent.opacity(0.08),
                    Color.clear
                ]),
                center: .center,
                startRadius: 10,
                endRadius: 300
            )
            .scaleEffect(glowScale)
            .opacity(glowOpacity)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Animated graduation ring
                ZStack {
                    // Outer decorative ring (subtle)
                    Circle()
                        .stroke(goldAccent.opacity(0.15), lineWidth: 2)
                        .frame(width: 220, height: 220)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Background track ring
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 12)
                        .frame(width: 180, height: 180)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Animated progress ring filling to 100%
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    goldAccent.opacity(0.6),
                                    goldAccent,
                                    goldAccent.opacity(0.9)
                                ]),
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Center number
                    VStack(spacing: 2) {
                        Text("66")
                            .font(.system(size: 68, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, goldAccent.opacity(0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Text("DAYS")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(goldAccent)
                            .tracking(6)
                    }
                    .scaleEffect(numberScale)
                    .opacity(numberOpacity)
                }

                Spacer().frame(height: 40)

                // Title and messaging
                VStack(spacing: 16) {
                    Text("HABIT FORMED")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [goldAccent, .white],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(3)
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)

                    Text(habitName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)
                }

                Spacer().frame(height: 20)

                // Motivational message
                Text("This is now part of who you are")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .italic()
                    .opacity(subtitleOpacity)

                Spacer()

                // Action buttons
                VStack(spacing: 14) {
                    // Share achievement button
                    Button(action: onShare) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Share Achievement")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(goldAccent)
                        )
                    }
                    .accessibilityLabel("Share your 66-day habit achievement for \(habitName)")

                    // Continue button
                    Button(action: onDismiss) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Dismiss graduation celebration")
                }
                .padding(.horizontal, 40)
                .opacity(buttonsOpacity)
                .padding(.bottom, 60)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Habit graduation celebration. \(habitName) has been formed after 66 days.")
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Sound and haptic feedback
        SoundManager.shared.playCelebrationSound()
        SoundManager.shared.triggerCelebrationHaptic()

        // Phase 1: Background fade in (0.3s)
        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 1
        }

        // Golden glow emerges
        withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
            glowScale = 1.0
            glowOpacity = 1.0
        }

        // Phase 2: Ring expands with spring (0.5s delay)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) {
            ringScale = 1.0
            ringOpacity = 1.0
        }

        // Ring fills to 100%
        withAnimation(.easeOut(duration: 1.2).delay(0.6)) {
            ringProgress = 1.0
        }

        // Phase 3: Number scales in with bounce (0.3s delay from ring)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.8)) {
            numberScale = 1.0
            numberOpacity = 1.0
        }

        // Phase 4: "HABIT FORMED" text fades in (0.5s delay from start of sequence)
        withAnimation(.easeOut(duration: 0.5).delay(1.1)) {
            titleOpacity = 1.0
            titleOffset = 0
        }

        // Phase 5: Subtitle and buttons fade in (0.7s delay from start)
        withAnimation(.easeOut(duration: 0.4).delay(1.3)) {
            subtitleOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.4).delay(1.5)) {
            buttonsOpacity = 1.0
        }
    }
}

// MARK: - Perfect Day Overlay

struct PerfectDayOverlay: View {
    let habitCount: Int
    let onDismiss: () -> Void

    private let accentColor = Color(hue: 0.10, saturation: 0.75, brightness: 0.95) // warm orange-gold

    // Animation states
    @State private var backgroundOpacity: Double = 0
    @State private var iconScale: CGFloat = 0
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.06, green: 0.07, blue: 0.09).opacity(backgroundOpacity * 0.92)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Checkmark icon with subtle ring
                ZStack {
                    Circle()
                        .stroke(accentColor.opacity(0.25), lineWidth: 3)
                        .frame(width: 130, height: 130)

                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 130, height: 130)

                    Image(systemName: "checkmark")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(accentColor)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                // Text content
                VStack(spacing: 12) {
                    Text("PERFECT DAY")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(accentColor)
                        .tracking(3)

                    Text("All \(habitCount) habits complete")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .opacity(textOpacity)

                Spacer()

                // Dismiss hint
                Text("Tap to continue")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .opacity(textOpacity)
                    .padding(.bottom, 60)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Perfect day. All \(habitCount) habits completed.")
        .onTapGesture { onDismiss() }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Sound and haptic
        SoundManager.shared.playCelebrationSound()
        SoundManager.shared.triggerCelebrationHaptic()

        // Phase 1: Background fade in (0.3s)
        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 1
        }

        // Phase 2: Icon scales in with spring (0.4s delay)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(0.4)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        // Phase 3: Text fades in (0.6s delay)
        withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
            textOpacity = 1.0
        }
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

#Preview("Streak Celebration") {
    CelebrationOverlay(
        milestone: .habitFormed,
        habitName: "Exercise",
        onDismiss: {}
    )
}

#Preview("Health Celebration") {
    HealthMilestoneOverlay(
        percentage: 50,
        habitName: "Meditate",
        onDismiss: {}
    )
}

#Preview("Habit Graduation") {
    HabitGraduationOverlay(
        habitName: "Exercise",
        onDismiss: {},
        onShare: {}
    )
}

#Preview("Perfect Day") {
    PerfectDayOverlay(
        habitCount: 5,
        onDismiss: {}
    )
}

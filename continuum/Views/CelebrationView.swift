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

struct CelebrationParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
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

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
        case .week: return "7 DAYS"
        case .threeWeeks: return "21 DAYS"
        case .habitFormed: return "66 DAYS"
        case .hundred: return "100 DAYS"
        case .year: return "365 DAYS"
        }
    }

    var subtitle: String {
        switch self {
        case .week: return "MOMENTUM INITIATED"
        case .threeWeeks: return "NEURAL PATHWAY FORMING"
        case .habitFormed: return "HABIT ENCODED"
        case .hundred: return "CENTURY PROTOCOL COMPLETE"
        case .year: return "ANNUAL CYCLE ACHIEVED"
        }
    }

    var systemCode: String {
        switch self {
        case .week: return "SYS.STREAK.007"
        case .threeWeeks: return "SYS.STREAK.021"
        case .habitFormed: return "SYS.STREAK.066"
        case .hundred: return "SYS.STREAK.100"
        case .year: return "SYS.STREAK.365"
        }
    }

    static func milestone(for streak: Int) -> StreakMilestone? {
        return StreakMilestone(rawValue: streak)
    }
}

// MARK: - Futuristic Celebration Overlay
struct CelebrationOverlay: View {
    let milestone: StreakMilestone
    let habitName: String
    let onDismiss: () -> Void

    @State private var ringScale: CGFloat = 0.3
    @State private var ringOpacity: Double = 0
    @State private var outerRingScale: CGFloat = 0.5
    @State private var textOpacity: Double = 0
    @State private var scanLineOffset: CGFloat = -200
    @State private var glowPulse: Double = 0.5
    @State private var dataStreamOpacity: Double = 0

    var body: some View {
        ZStack {
            // Dark background with grid
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .overlay(
                    GridPattern()
                        .opacity(0.1)
                )
                .onTapGesture {
                    onDismiss()
                }

            // Scanning line effect
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .orange.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 100)
                .offset(y: scanLineOffset)

            // Content
            VStack(spacing: 32) {
                // System code
                Text(milestone.systemCode)
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange.opacity(0.7))
                    .opacity(dataStreamOpacity)

                // Geometric rings
                ZStack {
                    // Outer pulsing ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.orange.opacity(0.3), .orange.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(outerRingScale)
                        .opacity(ringOpacity * 0.5)

                    // Middle ring
                    Circle()
                        .stroke(.orange.opacity(0.5), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Inner ring with glow
                    Circle()
                        .stroke(.orange, lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                        .shadow(color: .orange.opacity(glowPulse), radius: 20)

                    // Center diamond
                    Diamond()
                        .fill(.orange)
                        .frame(width: 20, height: 20)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                        .shadow(color: .orange, radius: 10)

                    // Corner accents
                    ForEach(0..<4) { i in
                        CornerAccent()
                            .stroke(.orange.opacity(0.6), lineWidth: 1)
                            .frame(width: 30, height: 30)
                            .offset(x: i % 2 == 0 ? -55 : 55, y: i < 2 ? -55 : 55)
                            .opacity(ringOpacity)
                    }
                }

                // Title
                VStack(spacing: 12) {
                    Text(milestone.title)
                        .font(.system(size: 42, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(8)

                    Text(milestone.subtitle)
                        .font(.caption.monospaced())
                        .foregroundStyle(.orange)
                        .tracking(4)

                    Rectangle()
                        .fill(.orange.opacity(0.5))
                        .frame(width: 100, height: 1)
                        .padding(.vertical, 8)

                    Text(habitName.uppercased())
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.gray)
                        .tracking(2)
                }
                .opacity(textOpacity)

                // Dismiss hint
                Text("[ TAP TO CONTINUE ]")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.gray.opacity(0.5))
                    .padding(.top, 40)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            // Trigger sound and haptics
            SoundManager.shared.playCelebrationSound()
            SoundManager.shared.triggerCelebrationHaptic()

            // Animate rings
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                ringScale = 1.0
                ringOpacity = 1.0
            }

            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                outerRingScale = 1.2
            }

            // Text fade in
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                textOpacity = 1.0
                dataStreamOpacity = 1.0
            }

            // Scan line animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                scanLineOffset = 400
            }

            // Glow pulse
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glowPulse = 1.0
            }
        }
    }
}

// MARK: - Health Milestone Overlay
struct HealthMilestoneOverlay: View {
    let percentage: Int
    let habitName: String
    let onDismiss: () -> Void

    @State private var ringProgress: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var glowIntensity: Double = 0.3

    private var milestoneText: String {
        switch percentage {
        case 25: return "25% INTEGRITY"
        case 50: return "50% INTEGRITY"
        case 75: return "75% INTEGRITY"
        case 100: return "MAXIMUM INTEGRITY"
        default: return "\(percentage)% INTEGRITY"
        }
    }

    private var subtitle: String {
        switch percentage {
        case 25: return "FOUNDATION ESTABLISHED"
        case 50: return "HALF PROTOCOL COMPLETE"
        case 75: return "APPROACHING OPTIMAL"
        case 100: return "PEAK PERFORMANCE ACHIEVED"
        default: return "PROGRESS LOGGED"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .overlay(
                    GridPattern()
                        .opacity(0.1)
                )
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 32) {
                Text("SYS.HEALTH.\(String(format: "%03d", percentage))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.green.opacity(0.7))
                    .opacity(textOpacity)

                // Animated ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 140, height: 140)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.orange, .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: .green.opacity(glowIntensity), radius: 15)

                    // Percentage text
                    VStack(spacing: 2) {
                        Text("\(percentage)")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("%")
                            .font(.caption.monospaced())
                            .foregroundStyle(.gray)
                    }
                }

                VStack(spacing: 12) {
                    Text(milestoneText)
                        .font(.title2.weight(.bold).monospaced())
                        .foregroundStyle(.white)
                        .tracking(2)

                    Text(subtitle)
                        .font(.caption.monospaced())
                        .foregroundStyle(.green)
                        .tracking(2)

                    Rectangle()
                        .fill(.green.opacity(0.5))
                        .frame(width: 80, height: 1)
                        .padding(.vertical, 8)

                    Text(habitName.uppercased())
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.gray)
                        .tracking(2)
                }
                .opacity(textOpacity)

                Text("[ TAP TO CONTINUE ]")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.gray.opacity(0.5))
                    .padding(.top, 40)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            SoundManager.shared.playCelebrationSound()
            SoundManager.shared.triggerCelebrationHaptic()

            withAnimation(.easeOut(duration: 1.2)) {
                ringProgress = CGFloat(percentage) / 100.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                textOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
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

struct CornerAccent: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 10))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + 10, y: rect.minY))
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

#Preview("Streak Celebration") {
    CelebrationOverlay(
        milestone: .habitFormed,
        habitName: "Morning Protocol",
        onDismiss: {}
    )
}

#Preview("Health Celebration") {
    HealthMilestoneOverlay(
        percentage: 50,
        habitName: "Exercise",
        onDismiss: {}
    )
}

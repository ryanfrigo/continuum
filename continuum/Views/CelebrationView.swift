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
        case .week: return "1 Week!"
        case .threeWeeks: return "3 Weeks!"
        case .habitFormed: return "Habit Formed!"
        case .hundred: return "100 Days!"
        case .year: return "1 Year!"
        }
    }

    var subtitle: String {
        switch self {
        case .week: return "You're building momentum"
        case .threeWeeks: return "The habit is taking root"
        case .habitFormed: return "Science says it's official"
        case .hundred: return "Triple digits! Incredible"
        case .year: return "A full year of dedication"
        }
    }

    var emoji: String {
        switch self {
        case .week: return "🔥"
        case .threeWeeks: return "🌱"
        case .habitFormed: return "🎯"
        case .hundred: return "💯"
        case .year: return "🏆"
        }
    }

    static func milestone(for streak: Int) -> StreakMilestone? {
        // Return milestone only if streak exactly matches
        return StreakMilestone(rawValue: streak)
    }
}

// MARK: - Confetti Particle
struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let rotationSpeed: Double
    var velocity: CGFloat
    let horizontalDrift: CGFloat
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    let colors: [Color] = [.orange, .yellow, .green, .cyan, .pink, .purple, .red]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Rectangle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size * 1.5)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                createParticles(in: geo.size)
                animateParticles(in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func createParticles(in size: CGSize) {
        particles = (0..<80).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...size.width),
                y: -20,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -180...180),
                velocity: CGFloat.random(in: 3...8),
                horizontalDrift: CGFloat.random(in: -2...2)
            )
        }
    }

    private func animateParticles(in size: CGSize) {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            withAnimation(.linear(duration: 0.016)) {
                for i in particles.indices {
                    particles[i].y += particles[i].velocity
                    particles[i].x += particles[i].horizontalDrift
                    particles[i].velocity += 0.15 // gravity
                }
            }

            // Stop when all particles have fallen
            if particles.allSatisfy({ $0.y > size.height + 50 }) {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Celebration Overlay
struct CelebrationOverlay: View {
    let milestone: StreakMilestone
    let habitName: String
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var emojiScale: CGFloat = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Confetti
            ConfettiView()
                .ignoresSafeArea()

            // Content
            VStack(spacing: 24) {
                // Emoji
                Text(milestone.emoji)
                    .font(.system(size: 80))
                    .scaleEffect(emojiScale)

                // Title
                VStack(spacing: 8) {
                    Text(milestone.title)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text(milestone.subtitle)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))

                    Text(habitName)
                        .font(.headline)
                        .foregroundStyle(.gray)
                        .padding(.top, 8)
                }
                .opacity(textOpacity)

                // Dismiss hint
                Text("Tap anywhere to continue")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.6))
                    .padding(.top, 40)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            // Haptic feedback
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif

            // Animate in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                emojiScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                textOpacity = 1.0
            }
        }
    }
}

// MARK: - Health Milestone Celebration
struct HealthMilestoneOverlay: View {
    let percentage: Int
    let habitName: String
    let onDismiss: () -> Void

    @State private var ringProgress: CGFloat = 0
    @State private var textOpacity: Double = 0

    private var milestoneText: String {
        switch percentage {
        case 25: return "Quarter Way!"
        case 50: return "Halfway There!"
        case 75: return "Almost There!"
        case 100: return "Perfect Health!"
        default: return "\(percentage)%"
        }
    }

    private var subtitle: String {
        switch percentage {
        case 25: return "You're building consistency"
        case 50: return "Solid foundation established"
        case 75: return "Excellence in progress"
        case 100: return "66 days of perfection"
        default: return "Keep going!"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            ConfettiView()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.orange, .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    Text("\(percentage)%")
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                }

                VStack(spacing: 8) {
                    Text(milestoneText)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))

                    Text(habitName)
                        .font(.headline)
                        .foregroundStyle(.gray)
                        .padding(.top, 8)
                }
                .opacity(textOpacity)

                Text("Tap anywhere to continue")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.6))
                    .padding(.top, 40)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif

            withAnimation(.easeOut(duration: 1.0)) {
                ringProgress = CGFloat(percentage) / 100.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                textOpacity = 1.0
            }
        }
    }
}

#Preview("Streak Celebration") {
    CelebrationOverlay(
        milestone: .habitFormed,
        habitName: "Morning Meditation",
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

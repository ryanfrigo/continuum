import SwiftUI

// MARK: - Design System
// Award-winning design constants and reusable components

enum ContinuumTheme {
    // MARK: - Colors

    static let backgroundPrimary = Color(red: 0.02, green: 0.02, blue: 0.03)
    static let backgroundCard = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let backgroundCardElevated = Color(red: 0.12, green: 0.12, blue: 0.13)

    static let accent = Color.orange
    static let accentSecondary = Color(hue: 0.08, saturation: 0.7, brightness: 0.95)

    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.6)
    static let textTertiary = Color(white: 0.4)

    // MARK: - Typography

    static func displayLarge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 56, weight: .black, design: .rounded))
            .tracking(-1)
    }

    static func displayMedium(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .tracking(-0.5)
    }

    static func headline(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold, design: .default))
    }

    static func monoLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(1.5)
    }

    static func monoData(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
    }

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32

    // MARK: - Radii

    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 16
    static let radiusXL: CGFloat = 20
    static let radiusXXL: CGFloat = 28

    // MARK: - Animation Curves

    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    static let springSmooth = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let easeOutQuick = Animation.easeOut(duration: 0.2)
    static let easeOutMedium = Animation.easeOut(duration: 0.4)
}

// MARK: - Glassmorphic Card Background

struct GlassmorphicBackground: View {
    let cornerRadius: CGFloat
    let glowColor: Color
    let glowIntensity: Double

    init(cornerRadius: CGFloat = 16, glowColor: Color = .orange, glowIntensity: Double = 0.5) {
        self.cornerRadius = cornerRadius
        self.glowColor = glowColor
        self.glowIntensity = glowIntensity
    }

    var body: some View {
        ZStack {
            // Base layer with subtle gradient
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.12),
                            Color(white: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Inner glow effect
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    RadialGradient(
                        colors: [
                            glowColor.opacity(0.15 * glowIntensity),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )

            // Subtle border
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            // Accent border glow
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(glowColor.opacity(0.3 * glowIntensity), lineWidth: 1)
                .blur(radius: 4)
        }
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double // 0.0 - 1.0
    let lineWidth: CGFloat
    let gradient: [Color]

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)

            // Progress
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: gradient + [gradient[0]],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Glow
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(gradient[0], lineWidth: lineWidth)
                .rotationEffect(.degrees(-90))
                .blur(radius: lineWidth)
                .opacity(0.5)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    let color: Color
    let size: CGFloat

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 0.5)

            // Core
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color, radius: 4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Animated Counter

struct AnimatedCounter: View {
    let value: Int
    let font: Font
    let color: Color

    @State private var animatedValue: Int = 0

    var body: some View {
        Text("\(animatedValue)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(animatedValue)))
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: 0.4)) {
                    animatedValue = newValue
                }
            }
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: -geometry.size.width * 0.25 + phase * geometry.size.width * 1.5)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Glow Effect

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius / 2)
            .shadow(color: color.opacity(0.3), radius: radius)
            .shadow(color: color.opacity(0.1), radius: radius * 2)
    }
}

extension View {
    func glow(color: Color, radius: CGFloat = 10) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Breathing Animation

struct BreathingModifier: ViewModifier {
    let intensity: CGFloat
    let duration: Double

    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    scale = 1.0 + intensity
                }
            }
    }
}

extension View {
    func breathing(intensity: CGFloat = 0.02, duration: Double = 3.0) -> some View {
        modifier(BreathingModifier(intensity: intensity, duration: duration))
    }
}

// MARK: - Premium Button Style

struct PremiumButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color)

                    // Inner highlight
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .foregroundStyle(.black)
            .font(.subheadline.weight(.bold))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .shadow(color: color.opacity(0.4), radius: configuration.isPressed ? 5 : 15)
    }
}

// MARK: - Preview

#Preview("Design System") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 30) {
            GlassmorphicBackground(glowColor: .orange, glowIntensity: 0.8)
                .frame(width: 200, height: 120)

            ProgressRing(
                progress: 0.75,
                lineWidth: 8,
                gradient: [.orange, .yellow, .orange]
            )
            .frame(width: 80, height: 80)

            HStack(spacing: 20) {
                PulsingDot(color: .orange, size: 8)
                PulsingDot(color: .green, size: 8)
                PulsingDot(color: .cyan, size: 8)
            }

            AnimatedCounter(
                value: 66,
                font: .system(size: 48, weight: .black, design: .rounded),
                color: .white
            )

            Button("Get Started") {}
                .buttonStyle(PremiumButtonStyle(color: .orange))
        }
    }
}

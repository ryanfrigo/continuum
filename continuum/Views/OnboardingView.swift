import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    var onComplete: () -> Void

    @State private var currentPage = 0
    @State private var showContent = false
    @State private var scanLineOffset: CGFloat = -100

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "square.grid.3x3.fill",
            title: "TRACK PROTOCOLS",
            subtitle: "DAILY HABIT MONITORING SYSTEM",
            description: "Log daily completions with precision. Each tap registers your progress in the system.",
            color: .orange
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "66 DAY PROTOCOL",
            subtitle: "NEURAL PATHWAY FORMATION",
            description: "Scientific research indicates 66 days to encode a habit. Monitor your progression toward permanence.",
            color: .green
        ),
        OnboardingPage(
            icon: "diamond.fill",
            title: "MILESTONE EVENTS",
            subtitle: "ACHIEVEMENT RECOGNITION SYSTEM",
            description: "System triggers at 7, 21, 66, and 100 day thresholds. Each milestone signifies deeper encoding.",
            color: .cyan
        ),
        OnboardingPage(
            icon: "waveform.path.ecg",
            title: "INTEGRITY INDEX",
            subtitle: "HABIT HEALTH MONITORING",
            description: "Real-time calculation of your 66-day completion percentage. Watch integrity rise from baseline to optimal.",
            color: .orange
        )
    ]

    var body: some View {
        ZStack {
            // Background with grid
            Color.black.ignoresSafeArea()
            GridPattern()
                .opacity(0.05)
                .ignoresSafeArea()

            // Scan line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .orange.opacity(0.1), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 150)
                .offset(y: scanLineOffset)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("SKIP") {
                        SoundManager.shared.playSubtleClick()
                        completeOnboarding()
                    }
                    .font(.caption.monospaced())
                    .foregroundStyle(.gray)
                    .padding()
                }

                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                Spacer()

                // Progress indicator
                HStack(spacing: 12) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Rectangle()
                            .fill(index == currentPage ? Color.orange : Color.gray.opacity(0.3))
                            .frame(width: index == currentPage ? 24 : 12, height: 2)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 30)

                // Next/Initialize button
                Button {
                    SoundManager.shared.playSubtleClick()
                    SoundManager.shared.triggerSelectionHaptic()

                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentPage < pages.count - 1 ? "NEXT" : "INITIALIZE")
                            .font(.subheadline.monospaced().weight(.bold))
                            .tracking(2)

                        Image(systemName: currentPage < pages.count - 1 ? "chevron.right" : "power")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.orange.opacity(0.5), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                showContent = true
            }
            // Continuous scan line
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                scanLineOffset = 500
            }
        }
    }

    private func completeOnboarding() {
        SoundManager.shared.playCelebrationSound()

        withAnimation(.easeOut(duration: 0.2)) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
            onComplete()
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var ringRotation: Double = 0

    var body: some View {
        VStack(spacing: 40) {
            // Geometric icon container
            ZStack {
                // Rotating outer ring
                Circle()
                    .stroke(page.color.opacity(0.2), lineWidth: 1)
                    .frame(width: 160, height: 160)

                // Dashed rotating ring
                Circle()
                    .stroke(page.color.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(ringRotation))

                // Inner ring
                Circle()
                    .stroke(page.color.opacity(0.5), lineWidth: 1)
                    .frame(width: 100, height: 100)

                // Icon
                Image(systemName: page.icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(page.color)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                // Corner brackets
                ForEach(0..<4) { i in
                    CornerBracket()
                        .stroke(page.color.opacity(0.6), lineWidth: 1)
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(Double(i) * 90))
                        .offset(
                            x: (i == 0 || i == 3) ? -70 : 70,
                            y: (i == 0 || i == 1) ? -70 : 70
                        )
                        .opacity(iconOpacity)
                }
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title2.weight(.black).monospaced())
                    .foregroundStyle(.white)
                    .tracking(4)

                Text(page.subtitle)
                    .font(.caption.monospaced())
                    .foregroundStyle(page.color)
                    .tracking(2)

                Rectangle()
                    .fill(page.color.opacity(0.3))
                    .frame(width: 60, height: 1)
                    .padding(.vertical, 8)

                Text(page.description)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
            }
            .opacity(textOpacity)
        }
        .padding()
        .onAppear {
            iconScale = 0.5
            iconOpacity = 0
            textOpacity = 0
            ringRotation = 0

            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                textOpacity = 1.0
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                ringRotation = 360
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

#Preview {
    OnboardingView(isPresented: .constant(true), onComplete: {})
}

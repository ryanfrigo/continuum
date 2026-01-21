import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    var onComplete: () -> Void

    @State private var currentPage = 0
    @State private var showContent = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "flame.fill",
            title: "Track Your Habits",
            description: "Build lasting habits by tracking your daily progress. Tap a habit card to mark it complete for the day.",
            color: .orange
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            title: "66 Day Journey",
            description: "Science shows it takes about 66 days to form a habit. Watch your progress grid fill up as you build consistency.",
            color: .green
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "Celebrate Milestones",
            description: "Get rewarded at 7, 21, 66, and 100 day streaks. Every milestone brings you closer to lasting change.",
            color: .cyan
        ),
        OnboardingPage(
            icon: "heart.fill",
            title: "Health Score",
            description: "Your habit health shows the percentage of the last 66 days you've completed. Watch it grow from orange to green!",
            color: .pink
        )
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.subheadline.weight(.medium))
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

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.orange : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.bottom, 30)

                // Next/Get Started button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.orange)
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
        }
    }

    private func completeOnboarding() {
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
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    @State private var iconScale: CGFloat = 0.5
    @State private var textOpacity: Double = 0

    var body: some View {
        VStack(spacing: 30) {
            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 180, height: 180)

                Image(systemName: page.icon)
                    .font(.system(size: 60))
                    .foregroundStyle(page.color)
                    .scaleEffect(iconScale)
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .opacity(textOpacity)
        }
        .padding()
        .onAppear {
            iconScale = 0.5
            textOpacity = 0
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                textOpacity = 1.0
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true), onComplete: {})
}

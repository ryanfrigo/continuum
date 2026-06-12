import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    var onComplete: ([String]) -> Void  // Returns selected habit names

    @State private var currentPage = 0
    @State private var showContent = false
    @State private var selectedHabits: Set<String> = []

    private let totalPages = 5  // 4 info pages + 1 habit selection

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "checkmark.circle.fill",
            title: "Track Daily",
            subtitle: "Build momentum",
            description: "Double-tap a habit card to complete it. Watch the progress bar fill as your streak grows.",
            color: .orange
        ),
        OnboardingPage(
            icon: "flame.fill",
            title: "66 Days",
            subtitle: "Form habits",
            description: "Science shows 66 days forms lasting habits. We'll guide you there.",
            color: .orange
        ),
        OnboardingPage(
            icon: "square.grid.3x3.fill",
            title: "The Grid",
            subtitle: "Your journey",
            description: "Each square is a day. Top-left is today, filling in as you build your streak to 66 days.",
            color: .orange
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Health Score",
            subtitle: "Track progress",
            description: "Your percentage shows consistency over the last 66 days.",
            color: .orange
        )
    ]

    private let habitSuggestions = [
        "5 AM Club",
        "Cold Plunge",
        "Meditate",
        "No Phone Till Noon",
        "Zone 2 Cardio",
        "Read 30 Pages",
        "Journal",
        "No Processed Food",
        "Lift Heavy",
        "Breathwork",
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark slate background
                Color(red: 0.08, green: 0.09, blue: 0.11)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Skip button
                    HStack {
                        Spacer()
                        Button {
                            SoundManager.shared.triggerSelectionHaptic()
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 8)

                    // Page content
                    TabView(selection: $currentPage) {
                        // Info pages
                        ForEach(0..<pages.count, id: \.self) { index in
                            OnboardingPageView(page: pages[index], isActive: currentPage == index)
                                .tag(index)
                        }

                        // Habit selection page
                        HabitSelectionPageView(
                            suggestions: habitSuggestions,
                            selectedHabits: $selectedHabits,
                            isActive: currentPage == pages.count
                        )
                        .tag(pages.count)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentPage)

                    // Bottom section
                    VStack(spacing: 24) {
                        // Progress indicator
                        HStack(spacing: 8) {
                            ForEach(0..<totalPages, id: \.self) { index in
                                Capsule()
                                    .fill(index == currentPage ? Color.orange : Color.white.opacity(0.2))
                                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                            }
                        }

                        // Action button
                        Button {
                            SoundManager.shared.triggerSelectionHaptic()
                            if currentPage < totalPages - 1 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentPage += 1
                                }
                            } else {
                                completeOnboarding()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(buttonText)
                                    .font(.system(size: 17, weight: .semibold))

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
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
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showContent = true
            }
        }
    }

    private var buttonText: String {
        if currentPage < pages.count {
            return "Continue"
        } else if selectedHabits.isEmpty {
            return "Start Fresh"
        } else {
            return "Get Started"
        }
    }

    private func completeOnboarding() {
        SoundManager.shared.playCelebrationSound()

        withAnimation(.easeOut(duration: 0.3)) {
            showContent = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
            onComplete(Array(selectedHabits))
        }
    }
}

// MARK: - Onboarding Page Data

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let color: Color
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        VStack(spacing: 48) {
            Spacer()

            // Clean icon with simple ring
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 120, height: 120)
                    .scaleEffect(iconScale)

                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 96, height: 96)
                    .scaleEffect(iconScale)

                Image(systemName: page.icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.orange)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
            }

            // Text content
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Text(page.subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.orange)
                }

                Text(page.description)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .opacity(textOpacity)

            Spacer()
            Spacer()
        }
        .padding()
        .onChange(of: isActive) { _, active in
            if active {
                runEntryAnimation()
            } else {
                resetAnimation()
            }
        }
        .onAppear {
            if isActive {
                runEntryAnimation()
            }
        }
    }

    private func runEntryAnimation() {
        iconScale = 0.5
        iconOpacity = 0
        textOpacity = 0

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
            textOpacity = 1.0
        }
    }

    private func resetAnimation() {
        iconScale = 0.5
        iconOpacity = 0
        textOpacity = 0
    }
}

// MARK: - Habit Selection Page

struct HabitSelectionPageView: View {
    let suggestions: [String]
    @Binding var selectedHabits: Set<String>
    let isActive: Bool

    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Text("Choose Habits")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Select a few to get started, or add your own later")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Habit chips grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(suggestions, id: \.self) { habit in
                    HabitChipView(
                        name: habit,
                        isSelected: selectedHabits.contains(habit)
                    ) {
                        SoundManager.shared.triggerSelectionHaptic()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            if selectedHabits.contains(habit) {
                                selectedHabits.remove(habit)
                            } else {
                                selectedHabits.insert(habit)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            // Selected count
            if !selectedHabits.isEmpty {
                Text("\(selectedHabits.count) habit\(selectedHabits.count == 1 ? "" : "s") selected")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.orange)
            }

            Spacer()
            Spacer()
        }
        .opacity(contentOpacity)
        .onChange(of: isActive) { _, active in
            if active {
                withAnimation(.easeOut(duration: 0.4)) {
                    contentOpacity = 1.0
                }
            } else {
                contentOpacity = 0
            }
        }
        .onAppear {
            if isActive {
                withAnimation(.easeOut(duration: 0.4)) {
                    contentOpacity = 1.0
                }
            }
        }
    }
}

// MARK: - Habit Chip View

struct HabitChipView: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(name)
                    .font(.system(size: 15, weight: .medium))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isPresented: .constant(true), onComplete: { _ in })
}

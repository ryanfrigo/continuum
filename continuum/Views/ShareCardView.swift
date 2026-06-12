import SwiftUI
import UIKit

// MARK: - Share Format

enum ShareFormat {
    case story   // 1080x1920
    case square  // 1080x1080

    var size: CGSize {
        switch self {
        case .story:  return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }

    var aspectRatio: CGFloat {
        size.width / size.height
    }
}

// MARK: - Share Card View

struct ShareCardView: View {
    let habit: Habit
    let format: ShareFormat

    private let habitFormationDays: Int = 66
    private let columnsCount: Int = 11

    // MARK: - Computed Properties

    private var health: Double {
        habit.habitHealth()
    }

    private var healthPercentage: Int {
        Int(health * 100)
    }

    private var streak: Int {
        habit.currentStreak()
    }

    private var themeColor: Color {
        healthColor(for: health)
    }

    private var gridFlags: [Bool] {
        var result = habit.historyCompletionFlags(daysBack: habitFormationDays)
        while result.count < habitFormationDays { result.append(false) }
        return Array(result.prefix(habitFormationDays).reversed())
    }

    // MARK: - Color System

    private func healthColor(for health: Double) -> Color {
        let hueOrange: Double = 30.0 / 360.0
        let hueGreen: Double = 140.0 / 360.0
        let hueCyan: Double = 175.0 / 360.0

        let clamped = max(0, min(1, health))

        if clamped <= 0.5 {
            let t = clamped / 0.5
            let hue = hueOrange + (hueGreen - hueOrange) * t
            return Color(hue: hue, saturation: 0.85, brightness: 0.95)
        } else {
            let t = (clamped - 0.5) / 0.5
            let hue = hueGreen + (hueCyan - hueGreen) * t
            return Color(hue: hue, saturation: 0.75, brightness: 0.9)
        }
    }

    // MARK: - Body

    var body: some View {
        let cardSize = format.size

        ZStack {
            // Background
            cardBackground

            // Content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: cardSize.height * 0.08)

                // App branding
                brandingHeader

                Spacer()
                    .frame(height: cardSize.height * 0.06)

                // Habit name
                habitNameSection

                Spacer()
                    .frame(height: cardSize.height * 0.04)

                // Streak number - the hero element
                streakSection

                Spacer()
                    .frame(height: cardSize.height * 0.05)

                // 66-day grid - visual centerpiece
                gridSection
                    .padding(.horizontal, 80)

                Spacer()
                    .frame(height: cardSize.height * 0.04)

                // Health ring and percentage
                healthSection

                Spacer()

                // Footer
                footerSection

                Spacer()
                    .frame(height: cardSize.height * 0.05)
            }
            .padding(.horizontal, 60)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipped()
    }

    // MARK: - Background

    private var cardBackground: some View {
        ZStack {
            // Base dark background
            Color(red: 0.08, green: 0.09, blue: 0.11)

            // Subtle radial gradient from theme color
            RadialGradient(
                colors: [
                    themeColor.opacity(0.15),
                    themeColor.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: format.size.height * 0.6
            )

            // Top-left accent glow
            RadialGradient(
                colors: [
                    themeColor.opacity(0.08),
                    Color.clear
                ],
                center: UnitPoint(x: 0.15, y: 0.1),
                startRadius: 0,
                endRadius: 400
            )

            // Bottom-right subtle warm glow
            RadialGradient(
                colors: [
                    themeColor.opacity(0.06),
                    Color.clear
                ],
                center: UnitPoint(x: 0.85, y: 0.9),
                startRadius: 0,
                endRadius: 350
            )

            // Very subtle noise texture via vertical lines
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.02),
                        Color.clear,
                        Color.white.opacity(0.01),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    // MARK: - Branding Header

    private var brandingHeader: some View {
        HStack(spacing: 8) {
            // Small decorative line
            Rectangle()
                .fill(themeColor.opacity(0.5))
                .frame(width: 24, height: 2)

            Text("CONTINUUM")
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .tracking(6)
                .foregroundStyle(Color.white.opacity(0.5))

            Rectangle()
                .fill(themeColor.opacity(0.5))
                .frame(width: 24, height: 2)
        }
    }

    // MARK: - Habit Name

    private var habitNameSection: some View {
        Text(habit.name.uppercased())
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .tracking(2)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.5)
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        VStack(spacing: 12) {
            // Large streak number
            Text("\(streak)")
                .font(.system(size: 160, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white,
                            themeColor.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: themeColor.opacity(0.4), radius: 30, x: 0, y: 10)

            // Label
            Text("DAY STREAK")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .tracking(4)
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }

    // MARK: - 66-Day Grid

    private var gridSection: some View {
        let flags = gridFlags
        let color = themeColor

        return VStack(spacing: 0) {
            // Grid label
            HStack {
                Text("66-DAY FORMATION")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.35))

                Spacer()

                Text("\(completedCount)/66")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(color.opacity(0.7))
            }
            .padding(.bottom, 16)

            // The grid itself
            GeometryReader { geo in
                let spacing: CGFloat = 6
                let availableWidth = geo.size.width
                let dotSize = floor((availableWidth - CGFloat(columnsCount - 1) * spacing) / CGFloat(columnsCount))
                let columns = Array(repeating: GridItem(.fixed(dotSize), spacing: spacing), count: columnsCount)

                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(0..<habitFormationDays, id: \.self) { idx in
                        let filled = flags[idx]
                        let isToday = idx == 0

                        RoundedRectangle(cornerRadius: dotSize * 0.2)
                            .fill(gridDotColor(filled: filled, isToday: isToday, healthColor: color))
                            .frame(width: dotSize, height: dotSize)
                            .overlay {
                                if filled {
                                    RoundedRectangle(cornerRadius: dotSize * 0.2)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.15),
                                                    Color.clear
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                if isToday && !filled {
                                    RoundedRectangle(cornerRadius: dotSize * 0.2)
                                        .stroke(color.opacity(0.6), lineWidth: 2)
                                }
                            }
                            .shadow(color: filled ? color.opacity(0.3) : .clear, radius: 4)
                    }
                }
            }
            .aspectRatio(gridAspectRatio, contentMode: .fit)
        }
    }

    private var gridAspectRatio: CGFloat {
        // 11 columns x 6 rows with spacing
        let spacing: CGFloat = 6
        let dotSize: CGFloat = 20 // Reference size for ratio calculation
        let width = CGFloat(columnsCount) * dotSize + CGFloat(columnsCount - 1) * spacing
        let rows = 6
        let height = CGFloat(rows) * dotSize + CGFloat(rows - 1) * spacing
        return width / height
    }

    private var completedCount: Int {
        gridFlags.filter { $0 }.count
    }

    private func gridDotColor(filled: Bool, isToday: Bool, healthColor: Color) -> Color {
        if filled {
            return healthColor
        } else if isToday {
            return Color.white.opacity(0.12)
        } else {
            return Color.white.opacity(0.08)
        }
    }

    // MARK: - Health Section

    private var healthSection: some View {
        HStack(spacing: 32) {
            // Progress ring
            ZStack {
                // Track
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)

                // Progress arc
                Circle()
                    .trim(from: 0, to: health)
                    .stroke(
                        AngularGradient(
                            colors: [themeColor, themeColor.opacity(0.6), themeColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Glow on progress
                Circle()
                    .trim(from: 0, to: health)
                    .stroke(themeColor, lineWidth: 8)
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 8)
                    .opacity(0.5)

                // Percentage inside ring
                Text("\(healthPercentage)%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 100, height: 100)

            // Health label
            VStack(alignment: .leading, spacing: 6) {
                Text("HABIT HEALTH")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.4))

                Text(healthDescription)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor)

                if streak >= 66 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                        Text("HABIT FORMED")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundStyle(themeColor)
                    .padding(.top, 4)
                }
            }
        }
    }

    private var healthDescription: String {
        switch healthPercentage {
        case 90...100: return "Excellent"
        case 75..<90:  return "Strong"
        case 50..<75:  return "Building"
        case 25..<50:  return "Growing"
        default:       return "Starting"
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 12) {
            // Separator
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            themeColor.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, 40)

            Text("Download Continuum")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.35))
        }
    }
}

// MARK: - Share Card Generator

final class ShareCardGenerator {
    @MainActor
    static func generateImage(habit: Habit, format: ShareFormat) -> UIImage? {
        let view = ShareCardView(habit: habit, format: format)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0 // Already at target pixel dimensions
        renderer.proposedSize = .init(format.size)

        return renderer.uiImage
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    var onComplete: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("Story Format") {
    let habit = Habit(name: "Meditate")

    ScrollView {
        ShareCardView(habit: habit, format: .story)
            .scaleEffect(0.3, anchor: .top)
            .frame(
                width: ShareFormat.story.size.width * 0.3,
                height: ShareFormat.story.size.height * 0.3
            )
    }
    .background(Color.black)
}

#Preview("Square Format") {
    let habit = Habit(name: "Exercise")

    ShareCardView(habit: habit, format: .square)
        .scaleEffect(0.35, anchor: .center)
        .frame(
            width: ShareFormat.square.size.width * 0.35,
            height: ShareFormat.square.size.height * 0.35
        )
        .background(Color.black)
}

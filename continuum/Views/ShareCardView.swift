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

    private var consistency: ConsistencyTally {
        habit.consistency
    }

    private var themeColor: Color {
        HabitPalette.color(HabitMath.colorProgress(consistency))
    }

    private var gridFlags: [Bool] {
        var result = habit.historyCompletionFlags(daysBack: habitFormationDays)
        while result.count < habitFormationDays { result.append(false) }
        return Array(result.prefix(habitFormationDays).reversed())
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

                // Consistency - the hero element
                heroSection

                Spacer()
                    .frame(height: cardSize.height * 0.05)

                // 66-day grid - visual centerpiece
                gridSection
                    .padding(.horizontal, 80)

                Spacer()
                    .frame(height: cardSize.height * 0.04)

                // Days done, and whether it's formed
                daysSection

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
        .fontDesign(.monospaced)
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

            Text("continuum")
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
            .font(.system(size: 44, weight: .bold, design: .monospaced))
            .tracking(2)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.5)
    }

    // MARK: - Consistency

    private var heroSection: some View {
        VStack(spacing: 14) {
            Text(consistency.percent.map { "\($0)%" } ?? "–")
                .font(.system(size: 120, weight: .semibold, design: .monospaced))
                .foregroundStyle(themeColor)
                // Phosphor glow, as on the app's readouts
                .shadow(color: themeColor.opacity(0.5), radius: 24)

            // Label
            Text("CONSISTENT")
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .tracking(6)
                .foregroundStyle(Color.white.opacity(0.5))

            if let trend = habit.consistencyTrend, trend != 0 {
                TrendLabel(trend: trend, color: themeColor, size: 22, suffix: " THIS WEEK")
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - 66-Day Grid

    private var gridSection: some View {
        let flags = gridFlags
        let color = themeColor
        // Days back to the first done day; older cells weren't misses
        let startIndex = habit.completedDayKeys.min().map { ContinuumDay.daysBetween($0, ContinuumDay.todayKey()) }

        return VStack(spacing: 0) {
            // Grid label
            HStack {
                Text("LAST 66 DAYS")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.35))

                Spacer()

                Text("\(consistency.done)/\(consistency.counted)")
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
                            .fill(gridDotColor(filled: filled, isToday: isToday,
                                               notStarted: startIndex.map { idx > $0 } ?? true,
                                               healthColor: color))
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

    private func gridDotColor(filled: Bool, isToday: Bool, notStarted: Bool, healthColor: Color) -> Color {
        HabitPalette.cell(filled: filled, isToday: isToday, notStarted: notStarted, color: healthColor)
    }

    // MARK: - Days Done

    private var daysSection: some View {
        VStack(spacing: 8) {
            Text("\(habit.daysDone)")
                .font(.system(size: 52, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)

            Text(habit.daysDone == 1 ? "DAY DONE" : "DAYS DONE")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.white.opacity(0.4))

            if habit.isGraduated {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                    Text("HABIT FORMED")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .tracking(2)
                }
                .foregroundStyle(HabitPalette.gold)
                .padding(.top, 8)
            }
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

            Text("Continuum: Consistency Tracker · on the App Store")
                .font(.system(size: 18, weight: .medium, design: .monospaced))
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

/// Where a shared habit card should send people. Shared by every share
/// entry point so a card never goes out without a way to get the app.
enum AppStoreLink {
    static let url = URL(string: "https://apps.apple.com/app/id6754441151")!

    /// Image first so Messages/Instagram still preview the card, with the
    /// link as a second item rather than burned into the picture.
    static func shareItems(with image: UIImage) -> [Any] {
        [image, url]
    }
}

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

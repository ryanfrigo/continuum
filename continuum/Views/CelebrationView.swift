import SwiftUI

// MARK: - Milestone Definitions

enum StreakMilestone: Int, CaseIterable {
    // Dense rewards early (days 1–7 decide retention), scarce later.
    case dayOne = 1
    case dayThree = 3
    case dayFive = 5
    case week = 7
    case threeWeeks = 21
    case habitFormed = 66
    case hundred = 100
    case year = 365

    var title: String {
        switch self {
        case .dayOne: return "1"
        case .dayThree: return "3"
        case .dayFive: return "5"
        case .week: return "7"
        case .threeWeeks: return "21"
        case .habitFormed: return "66"
        case .hundred: return "100"
        case .year: return "365"
        }
    }

    var subtitle: String {
        switch self {
        case .dayOne: return "day"
        default: return "days"
        }
    }

    var message: String {
        switch self {
        case .dayOne: return "The first mark is on the grid"
        case .dayThree: return "Three days. It's becoming real"
        case .dayFive: return "Five days. Momentum is yours"
        case .week: return "One week. You're someone who shows up"
        case .threeWeeks: return "21 days. This is becoming you"
        case .habitFormed: return "Habit formed"
        case .hundred: return "100 days. Few people get here"
        case .year: return "One year. This is who you are"
        }
    }

    /// Early milestones get a lighter celebration (no full takeover fatigue).
    var isMinor: Bool {
        switch self {
        case .dayOne, .dayThree, .dayFive: return true
        default: return false
        }
    }

    /// Celebration weight scales with how rare the milestone is.
    var intensity: CelebrationIntensity {
        switch self {
        case .dayOne, .dayThree, .dayFive: return .subtle
        case .week, .threeWeeks: return .strong
        case .habitFormed, .hundred, .year: return .full
        }
    }

    static func milestone(for streak: Int) -> StreakMilestone? {
        return StreakMilestone(rawValue: streak)
    }
}

// MARK: - Shared Celebration Design System
//
// Every celebration is the SAME card: dark fill, 1px accent border with a
// soft glow, identical typography scale and spacing. Only the accent color
// and content change. The accent follows the habit's progress color
// (orange → green → cyan) for habit moments; gold and ice are reserved for
// graduation/perfect/record and freeze moments.

enum CelebrationVisual {
    case value(String, unit: String)   // big number + unit ("7" / "DAYS")
    case icon(String)                  // SF symbol in a thin ring
    case sevenDots                     // perfect week row
}

enum CelebrationSound {
    case standard, rare
}

// MARK: - Intensity
//
// Celebration weight scales with rarity so the moments you hit daily stay
// quiet and the rare ones land. Day 1/3/5 are `subtle`; a 66-day graduation
// or personal record gets `full`.

enum CelebrationIntensity {
    case subtle    // day 1, 3, 5 — no ignition, minimal glow
    case medium    // perfect day, health milestones
    case strong    // day 7, 21, freeze save
    case full      // graduation, perfect week, personal record

    /// Brightness of the grid ignition wave (0 = no ignition at all).
    /// The wave always travels clear off-screen; only its intensity varies,
    /// so cells never freeze mid-flash.
    var ignitionStrength: Double {
        switch self {
        case .subtle: return 0
        case .medium: return 0.5
        case .strong: return 0.75
        case .full:   return 1.0
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .subtle: return 1
        case .medium: return 1.5
        case .strong, .full: return 2
        }
    }

    var borderOpacity: Double {
        switch self {
        case .subtle: return 0.45
        case .medium: return 0.65
        case .strong: return 0.8
        case .full:   return 0.95
        }
    }

    var glowRadius: CGFloat {
        switch self {
        case .subtle: return 18
        case .medium: return 28
        case .strong: return 38
        case .full:   return 52
        }
    }

    var showsBrackets: Bool {
        switch self {
        case .subtle: return false
        default: return true
        }
    }

    /// Light sweep across the numerals — reserved for the rare moments.
    var showsSweep: Bool {
        switch self {
        case .full: return true
        default: return false
        }
    }
}

// MARK: - Grid Ignition Backdrop
//
// The app's signature 66-day grid, used as the celebration itself: cells
// ignite in a wave radiating out from the card and settle into a faint
// residual glow. One Canvas rather than thousands of views, and it stops
// ticking once the wave has passed.

struct IgnitionGrid: View {
    let accent: Color
    let strength: Double

    @State private var startedAt: Date?
    @State private var isIgniting = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let duration: Double = 1.4

    var body: some View {
        Group {
            if isIgniting && !reduceMotion {
                TimelineView(.animation) { timeline in
                    canvas(elapsed: elapsed(at: timeline.date))
                }
            } else {
                // Settled state — the wave has passed, only residual glow left.
                canvas(elapsed: duration)
            }
        }
        .allowsHitTesting(false)
        .task {
            startedAt = Date()
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            isIgniting = false
        }
    }

    private func elapsed(at date: Date) -> Double {
        guard let startedAt else { return 0 }
        return date.timeIntervalSince(startedAt)
    }

    private func canvas(elapsed: Double) -> some View {
        Canvas { context, size in
            let cell: CGFloat = 7
            let step: CGFloat = 16
            let cols = Int(ceil(size.width / step)) + 1
            let rows = Int(ceil(size.height / step)) + 1

            let centerX = Double(cols - 1) / 2
            let centerY = Double(rows - 1) / 2
            let maxDistance = max(0.001, (centerX * centerX + centerY * centerY).squareRoot())

            // Ease the wave front out so it decelerates as it spreads. It
            // travels past 1.0 so it clears the screen and leaves nothing
            // stuck mid-flash behind it.
            let raw = min(1, max(0, elapsed / duration))
            let eased = pow(raw, 0.8)   // mild front-load: bursts, then eases out
            let front = eased * 1.55

            for row in 0..<rows {
                for col in 0..<cols {
                    let dx = Double(col) - centerX
                    let dy = Double(row) - centerY
                    let distance = (dx * dx + dy * dy).squareRoot() / maxDistance

                    let delta = front - distance
                    guard delta > 0 else { continue }

                    // Bright leading edge that decays sharply behind the front,
                    // over a very faint center-weighted residual afterglow.
                    let flash = max(0, 1 - delta * 3.5) * 0.85
                    let residual = 0.05 * max(0, 1 - distance * 1.15)
                    let alpha = min(0.8, (flash + residual) * strength)
                    guard alpha > 0.015 else { continue }

                    let rect = CGRect(
                        x: CGFloat(col) * step - cell / 2,
                        y: CGFloat(row) * step - cell / 2,
                        width: cell,
                        height: cell
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(accent.opacity(alpha))
                    )
                }
            }
        }
    }
}

// MARK: - Geometric Frame
//
// The card's edge, built from the same vocabulary as the 66-day grid: a
// precise dashed cell frame with a bright segment tracing around it. Reads
// as circuitry rather than a dialog outline.

struct GeometricFrame: View {
    let accent: Color
    var cornerRadius: CGFloat = 20
    var lineWidth: CGFloat = 2
    var tracing: Bool = true

    @State private var traceHead: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let traceLength: CGFloat = 0.16

    var body: some View {
        ZStack {
            // Dashed cell frame — evenly spaced ticks, no soft edges
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    accent.opacity(0.55),
                    style: StrokeStyle(lineWidth: lineWidth, dash: [5, 5])
                )

            // Bright segment travelling the perimeter
            if tracing && !reduceMotion {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .inset(by: lineWidth / 2)
                    .trim(from: traceHead, to: traceHead + traceLength)
                    .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .shadow(color: accent.opacity(0.9), radius: 6)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard tracing, !reduceMotion else { return }
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                traceHead = 1 - traceLength
            }
        }
    }
}

struct CelebrationCard: View {
    let accent: Color
    let visual: CelebrationVisual
    var title: String? = nil           // "PERFECT DAY" — tracked, accent
    var message: String? = nil         // sentence, white 60%
    var subject: String? = nil         // habit name, white 38%
    var meta: String? = nil            // "2 LEFT" / "3 WEEKS IN A ROW"
    var sound: CelebrationSound = .standard
    var intensity: CelebrationIntensity = .medium
    var autoDismissAfter: Double? = nil
    var primaryAction: (label: String, icon: String?, action: () -> Void)? = nil
    var secondaryActionLabel: String? = nil   // uses onDismiss
    let onDismiss: () -> Void

    // Animation states
    @State private var backgroundOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.93
    @State private var cardOpacity: Double = 0
    @State private var visualScale: CGFloat = 0.4
    @State private var visualOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var dotScales: [CGFloat] = Array(repeating: 0, count: 7)
    @State private var sweepX: CGFloat = -1

    private var hasButtons: Bool { primaryAction != nil || secondaryActionLabel != nil }

    var body: some View {
        ZStack {
            // Dim layer
            Color(red: 0.04, green: 0.05, blue: 0.07).opacity(backgroundOpacity * 0.94)
                .ignoresSafeArea()
                .onTapGesture { if !hasButtons { onDismiss() } }

            // Grid ignition — the 66-day grid motif as the celebration itself.
            // No blendMode here: it pushes the Canvas into its own compositing
            // group that draws over the card instead of behind it.
            if intensity.ignitionStrength > 0 {
                IgnitionGrid(accent: accent, strength: intensity.ignitionStrength)
                    .ignoresSafeArea()
                    .opacity(backgroundOpacity * 0.9)
                    .mask(
                        // A halo around the card that falls off before the edges,
                        // so the field frames the card instead of tiling the screen.
                        RadialGradient(
                            colors: [.white, .white.opacity(0.6), .clear],
                            center: .center,
                            startRadius: 60,
                            endRadius: 380
                        )
                        .ignoresSafeArea()
                    )
                    .onTapGesture { if !hasButtons { onDismiss() } }
                    .zIndex(0)
            }

            VStack(spacing: 22) {
                // ── The card ──
                VStack(spacing: 18) {
                    visualView
                        .scaleEffect(visualScale)
                        .opacity(visualOpacity)
                        .padding(.top, 6)

                    // Divider as a row of grid cells, not a plain rule —
                    // same vocabulary as the 66-day grid.
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(accent.opacity(i == 2 ? 0.85 : 0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .opacity(textOpacity)

                    VStack(spacing: 10) {
                        if let title {
                            Text(title)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(accent)
                                .tracking(3)
                                .multilineTextAlignment(.center)
                                .shadow(color: accent.opacity(0.6), radius: 12)
                        }

                        if let message {
                            Text(message)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }

                        if let subject {
                            Text(subject)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.38))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }

                        if let meta {
                            Text(meta.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(accent.opacity(0.75))
                                .tracking(1.5)
                                .padding(.top, 2)
                        }
                    }
                    .opacity(textOpacity)

                    if hasButtons {
                        VStack(spacing: 10) {
                            if let primary = primaryAction {
                                Button(action: primary.action) {
                                    HStack(spacing: 8) {
                                        if let icon = primary.icon {
                                            Image(systemName: icon)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        Text(primary.label)
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(accent))
                                }
                            }
                            if let secondary = secondaryActionLabel {
                                Button(action: onDismiss) {
                                    Text(secondary)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.6))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.top, 4)
                        .opacity(textOpacity)
                    }
                }
                .padding(28)
                .frame(maxWidth: 330)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.07, green: 0.08, blue: 0.10))
                )
                .overlay(
                    // Geometric dashed frame with a tracing segment. Subtle
                    // moments get a plain clean border instead.
                    Group {
                        if intensity.showsBrackets {
                            GeometricFrame(
                                accent: accent,
                                cornerRadius: 20,
                                lineWidth: intensity.borderWidth,
                                tracing: true
                            )
                            .opacity(textOpacity)
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    accent.opacity(intensity.borderOpacity),
                                    lineWidth: intensity.borderWidth
                                )
                        }
                    }
                )
                .shadow(color: accent.opacity(0.3), radius: intensity.glowRadius, y: 4)
                .scaleEffect(cardScale)
                .opacity(cardOpacity)

                // Dismiss hint (only for tap-anywhere cards)
                if !hasButtons {
                    Text("TAP TO CONTINUE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .tracking(2)
                        .opacity(textOpacity)
                }
            }
            .padding(.horizontal, 32)
            .zIndex(1)   // keep the card above the ignition field
        }
        .accessibilityElement(children: .contain)
        .onAppear { start() }
    }

    // MARK: Visual zone

    @ViewBuilder
    private var visualView: some View {
        switch visual {
        case .value(let value, let unit):
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 60, weight: .heavy, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, accent.opacity(0.85)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay {
                        // Light sweep across the numerals — rare moments only.
                        // Masked to the glyphs so it rides the digits, while the
                        // outer glow below stays unclipped.
                        if intensity.showsSweep {
                            GeometryReader { geo in
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.8), .clear],
                                    startPoint: .leading, endPoint: .trailing
                                )
                                .frame(width: max(20, geo.size.width * 0.5))
                                .offset(x: sweepX * geo.size.width)
                                .blendMode(.plusLighter)
                            }
                            .mask(
                                Text(value)
                                    .font(.system(size: 60, weight: .heavy, design: .monospaced))
                            )
                        }
                    }
                    .shadow(color: accent.opacity(0.5), radius: 18)
                Text(unit.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                    .tracking(5)
            }

        case .icon(let symbol):
            ZStack {
                Circle()
                    .fill(accent.opacity(0.10))
                    .frame(width: 76, height: 76)
                // Two concentric rings — reads as a target, not a plain bubble
                Circle()
                    .strokeBorder(accent.opacity(0.7), lineWidth: 2)
                    .frame(width: 76, height: 76)
                Circle()
                    .strokeBorder(accent.opacity(0.22), lineWidth: 1)
                    .frame(width: 90, height: 90)
                Image(systemName: symbol)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.7), radius: 12)
            }
            .shadow(color: accent.opacity(0.35), radius: 20)

        case .sevenDots:
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accent)
                        .frame(width: 18, height: 18)
                        .shadow(color: accent.opacity(0.5), radius: 4)
                        .scaleEffect(dotScales[i])
                }
            }
            .padding(.vertical, 14)
        }
    }

    // MARK: Animation + feedback

    private func start() {
        switch sound {
        case .standard: SoundManager.shared.playCelebrationSound()
        case .rare: SoundManager.shared.playRareCompletionSound()
        }
        SoundManager.shared.triggerCelebrationHaptic()

        withAnimation(.easeOut(duration: 0.25)) { backgroundOpacity = 1 }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8).delay(0.08)) {
            cardScale = 1.0
            cardOpacity = 1.0
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.28)) {
            visualScale = 1.0
            visualOpacity = 1.0
        }
        if case .sevenDots = visual {
            for i in 0..<7 {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55).delay(0.32 + Double(i) * 0.06)) {
                    dotScales[i] = 1.0
                }
            }
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.45)) { textOpacity = 1.0 }

        if intensity.showsSweep {
            sweepX = -1
            withAnimation(.easeInOut(duration: 1.1).delay(0.6)) { sweepX = 1.6 }
        }

        if let delay = autoDismissAfter {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { onDismiss() }
        }
    }
}

// MARK: - Shared accent palette

enum CelebrationPalette {
    static let gold = Color(hue: 0.12, saturation: 0.8, brightness: 0.95)
    static let ice = Color(hue: 0.52, saturation: 0.55, brightness: 0.95)
}

// MARK: - Streak Milestone Overlay

struct CelebrationOverlay: View {
    let milestone: StreakMilestone
    let habitName: String
    var accent: Color = .orange   // habit's current progress color
    let onDismiss: () -> Void

    var body: some View {
        CelebrationCard(
            accent: accent,
            visual: .value(milestone.title, unit: milestone.subtitle),
            message: milestone.message,
            subject: habitName,
            intensity: milestone.intensity,
            autoDismissAfter: milestone.isMinor ? 2.4 : nil,
            onDismiss: onDismiss
        )
        .accessibilityLabel("\(milestone.title) \(milestone.subtitle) milestone for \(habitName). \(milestone.message).")
    }
}

// MARK: - Health Milestone Overlay

struct HealthMilestoneOverlay: View {
    let percentage: Int
    let habitName: String
    var accent: Color = .orange   // habit's current progress color
    let onDismiss: () -> Void

    private var healthMessage: String {
        switch percentage {
        case 25: return "Quarter of the way to optimal"
        case 50: return "Halfway there. Keep it boring"
        case 75: return "Almost optimal"
        case 100: return "Perfect health. Machine mode"
        default: return "Progress achieved"
        }
    }

    var body: some View {
        CelebrationCard(
            accent: accent,
            visual: .value("\(percentage)", unit: "%"),
            title: "HEALTH",
            message: healthMessage,
            subject: habitName,
            intensity: percentage >= 100 ? .strong : .medium,
            onDismiss: onDismiss
        )
        .accessibilityLabel("\(percentage) percent health for \(habitName).")
    }
}

// MARK: - Habit Graduation Overlay

struct HabitGraduationOverlay: View {
    let habitName: String
    var accent: Color = CelebrationPalette.gold   // habit's tile color
    let onDismiss: () -> Void
    let onShare: () -> Void

    var body: some View {
        CelebrationCard(
            accent: accent,
            visual: .value("66", unit: "days"),
            title: "HABIT FORMED",
            message: "This isn't something you do anymore.\nIt's who you are.",
            subject: habitName,
            intensity: .full,
            primaryAction: ("Share Achievement", "square.and.arrow.up", onShare),
            secondaryActionLabel: "Continue",
            onDismiss: onDismiss
        )
        .accessibilityLabel("Habit graduation. \(habitName) has been formed after 66 days.")
    }
}

// MARK: - Perfect Day Overlay

struct PerfectDayOverlay: View {
    let habitCount: Int
    var accent: Color = CelebrationPalette.gold   // overall health tile color
    let onDismiss: () -> Void

    var body: some View {
        CelebrationCard(
            accent: accent,
            visual: .icon("checkmark"),
            title: "PERFECT DAY",
            message: habitCount == 1 ? "Habit complete" : "All \(habitCount) habits complete",
            intensity: .medium,
            autoDismissAfter: 2.4,
            onDismiss: onDismiss
        )
        .accessibilityLabel("Perfect day. All \(habitCount) habits completed.")
    }
}

// MARK: - Perfect Week Overlay

struct PerfectWeekOverlay: View {
    let habitCount: Int
    let weekCount: Int   // consecutive perfect weeks (1 = first)
    var accent: Color = CelebrationPalette.gold   // overall health tile color
    let onDismiss: () -> Void

    var body: some View {
        CelebrationCard(
            accent: accent,
            visual: .sevenDots,
            title: "PERFECT WEEK",
            message: "7 days. Every habit. Flawless.",
            meta: weekCount > 1 ? "\(weekCount) weeks in a row" : nil,
            sound: .rare,
            intensity: .full,
            onDismiss: onDismiss
        )
        .accessibilityLabel("Perfect week. All \(habitCount) habits completed every day for 7 days.")
    }
}

// MARK: - Streak Saved (Freeze) Overlay

struct FreezeSaveOverlay: View {
    let habitName: String
    let streak: Int
    let freezesLeft: Int
    let onDismiss: () -> Void

    var body: some View {
        CelebrationCard(
            accent: CelebrationPalette.ice,
            visual: .icon("snowflake"),
            title: "STREAK SAVED",
            message: "A freeze protected your \(streak)-day streak",
            subject: habitName,
            meta: freezesLeft > 0 ? "\(freezesLeft) freeze\(freezesLeft == 1 ? "" : "s") left" : nil,
            intensity: .strong,
            onDismiss: onDismiss
        )
        .accessibilityLabel("Streak saved. A freeze protected your \(streak)-day streak for \(habitName).")
    }
}

// MARK: - Personal Record Overlay

struct RecordOverlay: View {
    let habitName: String
    let streak: Int
    var accent: Color = CelebrationPalette.gold
    let onDismiss: () -> Void

    var body: some View {
        CelebrationCard(
            accent: accent,
            visual: .value("\(streak)", unit: "days"),
            title: "PERSONAL RECORD",
            message: "Your longest streak ever",
            subject: habitName,
            sound: .rare,
            intensity: .full,
            onDismiss: onDismiss
        )
        .accessibilityLabel("New personal record. \(streak)-day streak for \(habitName).")
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
    /// Arm length. Defaults to 8 so existing callers render unchanged.
    var length: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        return path
    }
}

// MARK: - Previews

#Preview("Day 7 Milestone") {
    CelebrationOverlay(milestone: .week, habitName: "Exercise", accent: .orange, onDismiss: {})
}

#Preview("Graduation") {
    HabitGraduationOverlay(habitName: "Exercise", onDismiss: {}, onShare: {})
}

#Preview("Perfect Day") {
    PerfectDayOverlay(habitCount: 5, onDismiss: {})
}

#Preview("Perfect Week") {
    PerfectWeekOverlay(habitCount: 4, weekCount: 2, onDismiss: {})
}

#Preview("Streak Saved") {
    FreezeSaveOverlay(habitName: "Meditate", streak: 23, freezesLeft: 2, onDismiss: {})
}

#Preview("Record") {
    RecordOverlay(habitName: "Run", streak: 31, onDismiss: {})
}

#Preview("Health") {
    HealthMilestoneOverlay(percentage: 50, habitName: "Read", onDismiss: {})
}

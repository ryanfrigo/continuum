import SwiftUI

/// A habit's colour on every screen and in the widget: dark orange through
/// yellow to green at 80% (strong), then green to blue at 100%. Where a habit
/// sits on the ramp is `HabitMath.colorProgress`. The app icon is a grid lit
/// along this ramp, with one missed day.
enum HabitPalette {
    /// Ramp stops as (position, hue in degrees, saturation, brightness).
    private static let stops: [(at: Double, hue: Double, saturation: Double, brightness: Double)] = [
        (0.00, 20, 0.86, 0.90),    // dark orange
        // A soft yellow, so orange-to-green doesn't flash a bright stripe
        (0.45, 55, 0.70, 0.90),    // yellow
        (0.80, 128, 0.64, 0.84),   // green: strong
        (0.90, 178, 0.74, 0.90),   // cyan
        (1.00, 214, 0.74, 0.98),   // blue
    ]

    static func color(_ progress: Double) -> Color {
        let p = max(0, min(1, progress))
        let i = stops.firstIndex { $0.at >= p } ?? stops.count - 1
        let b = stops[i]
        let a = i > 0 ? stops[i - 1] : b
        let t = b.at > a.at ? (p - a.at) / (b.at - a.at) : 0
        return Color(hue: (a.hue + (b.hue - a.hue) * t) / 360,
                     saturation: a.saturation + (b.saturation - a.saturation) * t,
                     brightness: a.brightness + (b.brightness - a.brightness) * t)
    }

    /// Chrome with no habit behind it (onboarding, settings, empty states):
    /// the colour every habit starts at.
    static let accent = color(0)

    /// Strong habits and full weeks: the one colour kept for rare moments.
    static let gold = Color(hue: 0.12, saturation: 0.8, brightness: 0.95)

    /// One square of a day grid, the same on every grid in the app and widget.
    /// Days before the first one done aren't misses, so they're fainter.
    static func cell(filled: Bool, isToday: Bool, notStarted: Bool, color: Color) -> Color {
        if filled { return color }
        if isToday { return .white.opacity(0.12) }
        return .white.opacity(notStarted ? 0.035 : 0.08)
    }
}

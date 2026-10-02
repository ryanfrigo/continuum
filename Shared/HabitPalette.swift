import SwiftUI

/// A habit's colour on every screen and in the widget: coral red while it's
/// new, through orange, yellow and green to blue as its grid fills. Where a
/// habit sits on the ramp is `HabitMath.colorProgress`. The app icon is a grid
/// lit along this ramp, coral to blue, with one missed day.
enum HabitPalette {
    /// Ramp stops as (position, hue in degrees, saturation, brightness).
    private static let stops: [(at: Double, hue: Double, saturation: Double, brightness: Double)] = [
        (0.00, 5, 0.66, 0.98),     // coral red
        (0.28, 28, 0.80, 0.97),    // orange
        // A soft yellow, so orange-to-green doesn't flash a bright stripe
        (0.44, 62, 0.66, 0.90),    // yellow
        (0.58, 128, 0.64, 0.84),   // green
        (0.80, 178, 0.74, 0.90),   // cyan
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

    /// Formed habits and full weeks: the one colour kept for rare moments.
    static let gold = Color(hue: 0.12, saturation: 0.8, brightness: 0.95)

    /// One square of a day grid, the same on every grid in the app and widget.
    /// Days before the first one done aren't misses, so they're fainter.
    static func cell(filled: Bool, isToday: Bool, notStarted: Bool, color: Color) -> Color {
        if filled { return color }
        if isToday { return .white.opacity(0.12) }
        return .white.opacity(notStarted ? 0.035 : 0.08)
    }
}

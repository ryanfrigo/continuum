import SwiftUI

/// A habit's colour on every screen and in the widget: dark red, orange,
/// gold, green and blue, evenly spaced from 0 to 100%. Where a habit
/// sits on the ramp is `HabitMath.colorProgress`. The app icon is a grid lit
/// along this ramp, with one missed day.
enum HabitPalette {
    /// Ramp stops as (position, hue in degrees, saturation, brightness).
    private static let stops: [(at: Double, hue: Double, saturation: Double, brightness: Double)] = [
        (0.000, -6, 0.80, 0.72),    // dark red (hue below 0 so it turns toward orange)
        (0.250, 22, 0.84, 0.95),    // orange
        (0.500, 43, 0.80, 0.97),    // gold
        // Softer in-betweens, so gold-to-green and green-to-blue don't
        // flash a neon stripe
        (0.625, 78, 0.60, 0.84),    // lime
        (0.750, 140, 0.56, 0.78),   // green
        (0.875, 184, 0.62, 0.78),   // teal
        (1.000, 222, 0.84, 0.82),   // deep blue
    ]

    static func color(_ progress: Double) -> Color {
        let p = max(0, min(1, progress))
        let i = stops.firstIndex { $0.at >= p } ?? stops.count - 1
        let b = stops[i]
        let a = i > 0 ? stops[i - 1] : b
        let t = b.at > a.at ? (p - a.at) / (b.at - a.at) : 0
        let hue = (a.hue + (b.hue - a.hue) * t + 360).truncatingRemainder(dividingBy: 360)
        return Color(hue: hue / 360,
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

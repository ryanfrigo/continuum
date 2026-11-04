import SwiftUI

/// A habit's colour on every screen and in the widget: dark red, orange,
/// yellow, green, then blue, purple and pink. Where a habit sits on the ramp
/// is `HabitMath.colorProgress`: a perfect first four weeks reaches green,
/// the rest takes months. The app icon is a grid lit along this ramp, with
/// one missed day.
enum HabitPalette {
    /// Ramp stops as (position, hue in degrees, saturation, brightness).
    private static let stops: [(at: Double, hue: Double, saturation: Double, brightness: Double)] = [
        (0.000, -6, 0.80, 0.72),    // dark red (hue below 0 so it turns toward orange)
        (0.140, 22, 0.84, 0.95),    // orange
        (0.280, 45, 0.80, 0.97),    // yellow
        // Softer in-betweens, so yellow-to-green and green-to-blue don't
        // flash a neon stripe
        (0.390, 82, 0.60, 0.86),    // lime
        (0.500, 140, 0.56, 0.80),   // green: a perfect first four weeks
        (0.590, 186, 0.60, 0.80),   // teal
        (0.680, 218, 0.74, 0.90),   // blue
        (0.840, 272, 0.58, 0.90),   // purple
        (1.000, 326, 0.52, 0.97),   // pink: months of it
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

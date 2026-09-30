import SwiftUI

/// A habit's colour on every screen and in the widget: coral red while it's
/// new, through orange and green to blue as its grid fills. Where a habit
/// sits on the ramp is `HabitMath.colorProgress`.
enum HabitPalette {
    /// Ramp stops as (position, hue in degrees, saturation, brightness).
    private static let stops: [(at: Double, hue: Double, saturation: Double, brightness: Double)] = [
        (0.00, 5, 0.66, 0.98),     // coral red
        (0.30, 30, 0.80, 0.97),    // orange
        (0.55, 135, 0.68, 0.88),   // green
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
}

import SwiftUI

/// A habit's colour on every screen and in the widget: ember, amber, green,
/// then blue and deep blue. Where a habit sits on the ramp is
/// `HabitMath.colorProgress`: a perfect first four weeks reaches green, the
/// rest takes months. The app icon is a grid lit along this ramp, with one
/// missed day.
enum HabitPalette {
    /// Ramp stops as (position, OKLCH lightness, chroma, hue in degrees).
    /// Mixed in OKLCH so brightness stays even between stops.
    private static let stops: [(at: Double, l: Double, c: Double, h: Double)] = [
        (0.00, 0.56, 0.17, 32),     // ember
        (0.25, 0.80, 0.15, 72),     // amber
        (0.50, 0.74, 0.17, 150),    // green: a perfect first four weeks
        (0.75, 0.66, 0.13, 215),    // blue
        (1.00, 0.58, 0.17, 262),    // deep blue: months of it
    ]

    static func color(_ progress: Double) -> Color {
        let p = max(0, min(1, progress))
        let i = stops.firstIndex { $0.at >= p } ?? stops.count - 1
        let b = stops[i]
        let a = i > 0 ? stops[i - 1] : b
        let t = b.at > a.at ? (p - a.at) / (b.at - a.at) : 0
        let (r, g, bl) = sRGB(l: a.l + (b.l - a.l) * t,
                              c: a.c + (b.c - a.c) * t,
                              h: a.h + (b.h - a.h) * t)
        return Color(.sRGB, red: r, green: g, blue: bl)
    }

    /// OKLCH to sRGB. Chroma comes down until the colour fits in sRGB, so
    /// a stop never clips to a different hue.
    private static func sRGB(l: Double, c: Double, h: Double) -> (Double, Double, Double) {
        let rad = h * .pi / 180
        var chroma = c
        while true {
            let a = chroma * cos(rad), b = chroma * sin(rad)
            let l_ = pow(l + 0.3963377774 * a + 0.2158037573 * b, 3)
            let m_ = pow(l - 0.1055613458 * a - 0.0638541728 * b, 3)
            let s_ = pow(l - 0.0894841775 * a - 1.2914855480 * b, 3)
            let linear = [
                4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
                -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
                -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_,
            ]
            if chroma <= 0 || linear.allSatisfy({ $0 >= -1e-4 && $0 <= 1.0001 }) {
                let v = linear.map { x -> Double in
                    let x = max(0, min(1, x))
                    return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
                }
                return (v[0], v[1], v[2])
            }
            chroma -= 0.004
        }
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

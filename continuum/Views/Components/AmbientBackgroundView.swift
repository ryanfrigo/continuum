import SwiftUI

// MARK: - Clean Dark Slate Background

struct AmbientBackgroundView: View {
    let healthPercentage: Double // 0.0 - 1.0 (kept for API compatibility)

    var body: some View {
        // Dark slate background (not pitch black)
        Color(red: 0.08, green: 0.09, blue: 0.11)
            .ignoresSafeArea()
    }
}

// MARK: - Floating Particles System (Minimal)

struct FloatingParticlesView: View {
    let particleCount: Int
    let baseColor: Color

    var body: some View {
        // Simplified - no particles for clean look
        Color.clear
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AmbientBackgroundView(healthPercentage: 0.7)
    }
}

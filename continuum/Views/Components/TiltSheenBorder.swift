import SwiftUI
import CoreMotion

/// A glint that slides around a completed card's border as the phone tilts,
/// like light catching a metal rim. Static under Reduce Motion or Low Power
/// Mode, and wherever there's no gyroscope (the simulator).
struct TiltSheenBorder: View {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    @State private var isTracking = false

    private var tilt: DeviceTilt { .shared }

    /// Resting position: glint at the top-left, where the light "is".
    private let restAngle: Double = -135

    private var angle: Double {
        guard isTracking else { return restAngle }
        // Roll sweeps the glint around the rim; pitch nudges it
        return restAngle + tilt.x * 110 + tilt.z * 40
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0), location: 0.00),
                        .init(color: .white.opacity(0.85), location: 0.06),
                        .init(color: .white.opacity(0), location: 0.14),
                        .init(color: .white.opacity(0), location: 0.46),
                        .init(color: .white.opacity(0.35), location: 0.53),
                        .init(color: .white.opacity(0), location: 0.60),
                        .init(color: .white.opacity(0), location: 1.00),
                    ]),
                    center: .center,
                    angle: .degrees(angle)
                ),
                lineWidth: lineWidth
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .modifier(TiltTracking(isTracking: $isTracking))
    }
}

/// A soft diagonal band of light that slides across its bounds as the phone
/// tilts. Mask it to a shape to make that shape catch the light. Draws
/// nothing when tilt isn't tracked — a frozen stripe would just look like a
/// rendering glitch.
struct TiltSheenFill: View {
    var intensity: Double = 0.45

    @State private var isTracking = false

    private var tilt: DeviceTilt { .shared }

    var body: some View {
        GeometryReader { geo in
            let span = max(geo.size.width, geo.size.height)
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(intensity), .white.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: span * 0.45, height: span * 3)
            .rotationEffect(.degrees(25))
            // Roll sweeps the band across; pitch nudges it
            .position(
                x: geo.size.width * (0.5 + tilt.x * 1.1 + tilt.z * 0.3),
                y: geo.size.height / 2
            )
        }
        .opacity(isTracking ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .modifier(TiltTracking(isTracking: $isTracking))
    }
}

/// Starts and stops the shared motion stream with the view's lifetime,
/// honoring Reduce Motion, Low Power Mode and the app being in the background.
private struct TiltTracking: ViewModifier {
    @Binding var isTracking: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { updateTracking() }
            .onDisappear { setTracking(false) }
            .onChange(of: scenePhase) { updateTracking() }
            .onChange(of: reduceMotion) { updateTracking() }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                updateTracking()
            }
    }

    private func updateTracking() {
        setTracking(scenePhase == .active
                    && !reduceMotion
                    && !ProcessInfo.processInfo.isLowPowerModeEnabled
                    && DeviceTilt.shared.isAvailable)
    }

    private func setTracking(_ on: Bool) {
        guard on != isTracking else { return }
        isTracking = on
        on ? DeviceTilt.shared.retain() : DeviceTilt.shared.release()
    }
}

/// One shared motion stream for every card, running only while at least one
/// sheen is on screen.
@Observable
final class DeviceTilt {
    static let shared = DeviceTilt()

    /// Low-passed gravity components, each in -1...1.
    private(set) var x: Double = 0
    private(set) var z: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var users = 0

    var isAvailable: Bool { manager.isDeviceMotionAvailable || fakeTilt != nil }

    /// DEBUG only: `SIMCTL_CHILD_FAKE_TILT=0.3` pins a tilt so the simulator,
    /// which has no gyroscope, can show the sheen for screenshots.
    @ObservationIgnored private let fakeTilt: Double? = {
        #if DEBUG
        ProcessInfo.processInfo.environment["FAKE_TILT"].flatMap(Double.init)
        #else
        nil
        #endif
    }()

    func retain() {
        users += 1
        if let fakeTilt { x = fakeTilt; return }
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let g = motion?.gravity else { return }
            // Smooth out hand tremor so the glint drifts rather than jitters
            self.x += (g.x - self.x) * 0.2
            self.z += (g.z - self.z) * 0.2
        }
    }

    func release() {
        users = max(0, users - 1)
        if users == 0 { manager.stopDeviceMotionUpdates() }
    }
}

import AVFoundation
import CoreHaptics
import SwiftUI

/// Sound and haptics.
///
/// Three rules, from Apple's audio-haptic guidance (WWDC19 810):
/// causality — feedback must obviously belong to what caused it; harmony —
/// audio and haptics share tempo; utility — judge it at the 100th use, not
/// the first. The chained multi-pulse patterns this file used to fire were
/// past the perceptual smear limit and read as a glitch once you'd felt them
/// a hundred times.
class SoundManager {
    @AppStorage("soundEnabled") static var soundEnabled: Bool = true
    @AppStorage("hapticsEnabled") static var hapticsEnabled: Bool = true

    static let shared = SoundManager()

    // MARK: Audio

    private let engine = AVAudioEngine()
    /// Two nodes: one beep must not cut off the previous one. A single node
    /// with `.interrupts` truncated the first tone mid-cycle — an audible click.
    private let playerNodes = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private var nextNode = 0
    private let sampleRate: Double = 44100
    private lazy var audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)

    // MARK: Haptics

    /// Held as properties and prepared on touch-down. Allocating a generator
    /// and calling prepare() immediately before firing gives no latency
    /// benefit — prepare() needs real lead time to spin the Taptic Engine up.
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private var hapticEngine: CHHapticEngine?
    private var holdPlayer: CHHapticPatternPlayer?

    /// Custom patterns need real Taptic hardware: no iPad, no simulator, and
    /// Low Power Mode shuts the engine down.
    private var supportsCustomHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var hapticsAllowed: Bool {
        SoundManager.hapticsEnabled && !UIAccessibility.isVoiceOverRunning
    }

    private init() {
        setupAudioSession()
        for node in playerNodes {
            engine.attach(node)
            if let format = audioFormat {
                // Connected once. Reconnecting per beep mutates the graph
                // mid-playback, which is both expensive and glitchy.
                engine.connect(node, to: engine.mainMixerNode, format: format)
            }
        }
        startEngine()
        prepareHapticEngine()
    }

    private func setupAudioSession() {
        do {
            // .ambient is silenced by the ring switch (no public API can read
            // it) and mixes rather than stopping someone's podcast.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    // MARK: - Hold-to-complete haptics

    /// Call on touch-down: warms the generators and plays a ladder of
    /// transients whose gaps compress as the bar fills. Accelerating intervals
    /// read as charging up; a continuous vibration for 900ms reads as mush.
    func startHoldFeedback(duration: Double) {
        guard hapticsAllowed else { return }
        impactRigid.prepare()
        impactLight.prepare()

        guard supportsCustomHaptics, let hapticEngine else {
            // Fallback: the fill bar still carries the progress visually
            selection.selectionChanged()
            return
        }

        // Sharpness maps to Taptic drive frequency, so "crisp" lives at 0.75+;
        // below ~0.4 feels like rubber. Intensity under 0.3 is imperceptible.
        let steps: [(time: Double, intensity: Float, sharpness: Float)] = [
            (0.00, 0.35, 0.75),
            (0.31, 0.45, 0.80),
            (0.56, 0.55, 0.85),
            (0.76, 0.68, 0.90),
            (0.91, 0.80, 1.00),
        ]
        let scale = duration / 0.9   // authored against the 0.9s hold

        var events = steps.map { step in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: step.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: step.sharpness),
                ],
                relativeTime: step.time * scale
            )
        }
        // The payoff: a full-sharpness click on top of a short dull body.
        // Click plus thunk is what reads as "candy" rather than "buzz".
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.30),
            ],
            relativeTime: duration,
            duration: 0.12
        ))

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            holdPlayer = try hapticEngine.makePlayer(with: pattern)
            try hapticEngine.start()
            try holdPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Hold haptic failed: \(error)")
        }
    }

    /// Call when the hold is released early: stop the ladder and land one dull
    /// thud, so "nothing happened" is legible without being punishing.
    func cancelHoldFeedback() {
        try? holdPlayer?.stop(atTime: CHHapticTimeImmediate)
        holdPlayer = nil
        guard hapticsAllowed else { return }
        impactSoft.impactOccurred(intensity: 0.25)
    }

    /// Call when the hold completes: the ladder already landed its own click.
    func finishHoldFeedback() {
        holdPlayer = nil
    }

    private func prepareHapticEngine() {
        guard supportsCustomHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            // The system stops the engine for its own reasons; without these
            // the first haptic after a phone call or camera use is silent.
            engine.resetHandler = { [weak self] in try? self?.hapticEngine?.start() }
            engine.stoppedHandler = { _ in }
            engine.playsHapticsOnly = true
            try engine.start()
            hapticEngine = engine
        } catch {
            print("Haptic engine unavailable: \(error)")
        }
    }

    // MARK: - Discrete haptics

    /// Completion: one firm hit. The old version chained a second impact 50ms
    /// later, which at that spacing smears rather than reading as two taps.
    func triggerCompletionHaptic() {
        guard hapticsAllowed else { return }
        impactRigid.impactOccurred(intensity: 1.0)
    }

    /// A celebration appeared — in a tile or full screen.
    func triggerCelebrationHaptic() {
        guard hapticsAllowed else { return }
        notification.notificationOccurred(.success)
    }

    /// Rare "golden" completion. Success plus a single bright transient: the
    /// old four-impact chain was the textbook 100th-use annoyance.
    func triggerRareHaptic() {
        guard hapticsAllowed else { return }
        notification.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.impactRigid.impactOccurred(intensity: 0.9)
        }
    }

    func triggerSelectionHaptic() {
        guard hapticsAllowed else { return }
        selection.selectionChanged()
    }

    /// Warm the generators ahead of an imminent tap.
    func prepareSelection() {
        guard hapticsAllowed else { return }
        selection.prepare()
    }

    // MARK: - Sound

    func playCompletionBeep() {
        guard SoundManager.soundEnabled else { return }
        playTone(frequency: 880, duration: 0.08)                     // A5
        playTone(frequency: 1320, duration: 0.06, startOffset: 0.06) // E6
    }

    func playSubtleClick() {
        guard SoundManager.soundEnabled else { return }
        playTone(frequency: 1200, duration: 0.03)
    }

    func playCelebrationSound() {
        guard SoundManager.soundEnabled else { return }
        let notes: [(Double, Double)] = [(440, 0.0), (554, 0.08), (659, 0.16), (880, 0.24)]
        for (frequency, offset) in notes {
            playTone(frequency: frequency, duration: 0.12, startOffset: offset)
        }
    }

    func playRareCompletionSound() {
        guard SoundManager.soundEnabled else { return }
        let notes: [(Double, Double, Double)] = [
            (659, 0.0, 0.10), (784, 0.07, 0.10), (988, 0.14, 0.10),
            (1319, 0.21, 0.16), (1976, 0.30, 0.22),
        ]
        for (frequency, offset, duration) in notes {
            playTone(frequency: frequency, duration: duration, startOffset: offset)
        }
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            print("Audio engine start failed: \(error)")   // non-fatal: no sound
        }
    }

    private var canPlayAudio: Bool {
        if !engine.isRunning { startEngine() }
        return engine.isRunning
    }

    /// One tone, scheduled on the audio clock rather than dispatched later —
    /// main-queue timing jitters by a frame, and audio-haptic sync is the
    /// whole illusion.
    private func playTone(frequency: Double, duration: Double, startOffset: Double = 0) {
        guard canPlayAudio, let format = audioFormat else { return }
        let samples = Int(sampleRate * duration)
        guard samples > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples)),
              let channel = buffer.floatChannelData?[0] else { return }

        buffer.frameLength = AVAudioFrameCount(samples)
        // ~2ms attack, exponential decay. The old 20ms linear attack removed
        // the transient entirely, which is what made a sine read "beepy".
        let attack = max(1.0, sampleRate * 0.002)
        for i in 0..<samples {
            let time = Double(i) / sampleRate
            let rise = min(1.0, Double(i) / attack)
            let decay = exp(-3.2 * time / duration)
            let body = sin(2.0 * .pi * frequency * time)
            // A touch of second harmonic: pure sines have no bite.
            let harmonic = 0.18 * sin(4.0 * .pi * frequency * time)
            channel[i] = Float((body + harmonic) * rise * decay * 0.28)
        }

        let node = playerNodes[nextNode]
        nextNode = (nextNode + 1) % playerNodes.count
        node.play()
        if startOffset <= 0 {
            node.scheduleBuffer(buffer, at: nil)
        } else {
            let start = AVAudioTime(
                sampleTime: (node.lastRenderTime?.sampleTime ?? 0) + AVAudioFramePosition(sampleRate * startOffset),
                atRate: sampleRate
            )
            node.scheduleBuffer(buffer, at: start)
        }
    }
}

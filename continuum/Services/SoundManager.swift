import AVFoundation
import SwiftUI

class SoundManager {
    @AppStorage("soundEnabled") static var soundEnabled: Bool = true
    @AppStorage("hapticsEnabled") static var hapticsEnabled: Bool = true

    static let shared = SoundManager()

    private var audioPlayer: AVAudioPlayer?
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private init() {
        setupAudioSession()
        engine.attach(playerNode)
        // Connect with a default format so the graph is valid before starting
        let defaultFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        if let fmt = defaultFormat {
            engine.connect(playerNode, to: engine.mainMixerNode, format: fmt)
        }
        startEngine()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    // MARK: - Electronic Beep Sound

    /// Plays a futuristic electronic confirmation beep
    func playCompletionBeep() {
        guard SoundManager.soundEnabled else { return }
        // Generate a clean electronic beep using audio synthesis
        generateElectronicBeep(frequency: 880, duration: 0.08) // A5 note

        // Add a second harmonic beep slightly delayed for richness
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            self.generateElectronicBeep(frequency: 1320, duration: 0.06) // E6 note
        }
    }

    /// Plays a subtle UI interaction sound
    func playSubtleClick() {
        guard SoundManager.soundEnabled else { return }
        generateElectronicBeep(frequency: 1200, duration: 0.03)
    }

    /// Plays a celebration sound for milestones
    func playCelebrationSound() {
        guard SoundManager.soundEnabled else { return }
        // Ascending arpeggio
        let notes: [(frequency: Double, delay: Double)] = [
            (440, 0.0),    // A4
            (554, 0.08),   // C#5
            (659, 0.16),   // E5
            (880, 0.24),   // A5
        ]

        for note in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + note.delay) {
                self.generateElectronicBeep(frequency: note.frequency, duration: 0.12)
            }
        }
    }

    /// Rare "golden" completion — a longer pentatonic shimmer.
    /// Fires on ~1 in 15 completions (variable reward).
    func playRareCompletionSound() {
        guard SoundManager.soundEnabled else { return }
        let notes: [(frequency: Double, delay: Double, duration: Double)] = [
            (659, 0.0, 0.10),    // E5
            (784, 0.07, 0.10),   // G5
            (988, 0.14, 0.10),   // B5
            (1319, 0.21, 0.16),  // E6
            (1976, 0.30, 0.22),  // B6 — the sparkle on top
        ]
        for note in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + note.delay) {
                self.generateElectronicBeep(frequency: note.frequency, duration: note.duration)
            }
        }
    }

    /// Heavier haptic for rare completions
    func triggerRareHaptic() {
        guard SoundManager.hapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        for i in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                let pulse = UIImpactFeedbackGenerator(style: i % 2 == 0 ? .rigid : .soft)
                pulse.impactOccurred(intensity: min(1.0, 0.5 + Double(i) * 0.15))
            }
        }
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            // Non-fatal — sounds just won't play
            print("Audio engine start failed: \(error)")
        }
    }

    /// Safe check before any audio operation
    private var canPlayAudio: Bool {
        if !engine.isRunning {
            startEngine()
        }
        return engine.isRunning
    }

    private func generateElectronicBeep(frequency: Double, duration: Double) {
        guard canPlayAudio else { return }
        let sampleRate: Double = 44100
        let samples = Int(sampleRate * duration)

        var audioData = [Float](repeating: 0, count: samples)

        for i in 0..<samples {
            let time = Double(i) / sampleRate
            let envelope = min(1.0, min(time * 50, (duration - time) * 50)) // Quick attack/release
            let sample = sin(2.0 * .pi * frequency * time) * envelope * 0.3
            audioData[i] = Float(sample)
        }

        // Create audio buffer and play
        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            print("Failed to create audio format")
            return
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(samples)) else { return }

        buffer.frameLength = AVAudioFrameCount(samples)
        guard let channelData = buffer.floatChannelData?[0] else { return }
        for i in 0..<samples {
            channelData[i] = audioData[i]
        }

        // Reconnect player node with the current format
        engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)

        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
        playerNode.play()
    }

    // MARK: - Haptic Feedback

    /// Futuristic sharp haptic for completion
    func triggerCompletionHaptic() {
        guard SoundManager.hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)

        // Double tap feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let second = UIImpactFeedbackGenerator(style: .light)
            second.impactOccurred(intensity: 0.6)
        }
    }

    /// Celebration haptic pattern
    func triggerCelebrationHaptic() {
        guard SoundManager.hapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)

        // Follow up with rhythmic pulses
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                let pulse = UIImpactFeedbackGenerator(style: .soft)
                pulse.impactOccurred(intensity: 1.0 - Double(i) * 0.2)
            }
        }
    }

    /// Subtle selection haptic
    func triggerSelectionHaptic() {
        guard SoundManager.hapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

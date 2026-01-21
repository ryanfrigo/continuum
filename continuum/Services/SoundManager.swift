import AVFoundation
import UIKit

class SoundManager {
    static let shared = SoundManager()

    private var audioPlayer: AVAudioPlayer?
    private var synthesizer: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    private init() {
        setupAudioSession()
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
        // Generate a clean electronic beep using audio synthesis
        generateElectronicBeep(frequency: 880, duration: 0.08) // A5 note

        // Add a second harmonic beep slightly delayed for richness
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            self.generateElectronicBeep(frequency: 1320, duration: 0.06) // E6 note
        }
    }

    /// Plays a subtle UI interaction sound
    func playSubtleClick() {
        generateElectronicBeep(frequency: 1200, duration: 0.03)
    }

    /// Plays a celebration sound for milestones
    func playCelebrationSound() {
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

    private func generateElectronicBeep(frequency: Double, duration: Double) {
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
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(samples)) else { return }

        buffer.frameLength = AVAudioFrameCount(samples)
        let channelData = buffer.floatChannelData![0]
        for i in 0..<samples {
            channelData[i] = audioData[i]
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: audioFormat)

        do {
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()

            // Keep engine alive for duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
                player.stop()
                engine.stop()
            }
        } catch {
            print("Audio engine error: \(error)")
        }
    }

    // MARK: - Haptic Feedback

    /// Futuristic sharp haptic for completion
    func triggerCompletionHaptic() {
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
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

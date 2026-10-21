import AVFoundation
import Foundation

enum SynthError: Error {
    case formatUnavailable
}

enum ReedSound: Int, CaseIterable, Identifiable, Sendable {
    case musette
    case clarinet
    case bassoon
    case violin
    case bandoneon

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .musette: "Musette"
        case .clarinet: "Clarinet"
        case .bassoon: "Bassoon"
        case .violin: "Violin"
        case .bandoneon: "Bandoneon"
        }
    }
}

private struct ReedRecipe {
    var detune: Float
    var left: Float
    var center: Float
    var right: Float
    var h1: Float
    var h2: Float
    var h3: Float
    var h4: Float
    var cutoff: Float
    var lowHz: Float

    static let all: [ReedRecipe] = [
        ReedRecipe(detune: cents(12), left: 0.34, center: 0.40, right: 0.26, h1: 1, h2: 0.42, h3: 0.22, h4: 0.08, cutoff: 1, lowHz: 240),
        ReedRecipe(detune: 1, left: 0, center: 1, right: 0, h1: 1, h2: 0.04, h3: 0.48, h4: 0.06, cutoff: 0.75, lowHz: 200),
        ReedRecipe(detune: 1, left: 0, center: 1, right: 0, h1: 1, h2: 0.52, h3: 0.10, h4: 0.03, cutoff: 0.48, lowHz: 90),
        ReedRecipe(detune: cents(6), left: 0.18, center: 0.58, right: 0.24, h1: 1, h2: 0.32, h3: 0.30, h4: 0.18, cutoff: 1.35, lowHz: 320),
        ReedRecipe(detune: cents(8), left: 0.48, center: 0.08, right: 0.44, h1: 1, h2: 0.58, h3: 0.16, h4: 0.04, cutoff: 0.9, lowHz: 150),
    ]

    private static func cents(_ value: Float) -> Float {
        Float(pow(2.0, Double(value) / 1200.0))
    }
}

/// Free-reed voices. Loudness is bellows pressure times the key gate.
final class ReedEngine: @unchecked Sendable {
    private struct Voice {
        var midi: Int = -1
        var env: Float = 0
        var phase0: Float = 0
        var phase1: Float = 0
        var phase2: Float = 0
        var highCut: Float = 0
        var lowCut: Float = 0
    }

    private static let voiceCount = 21

    private let lock = NSLock()
    private var requestedNotes = [Int](repeating: -1, count: voiceCount)
    private var requestedPressure: Float = 0
    private var requestedBrightness: Float = 0.5
    private var requestedSustain: Float = 0.15
    private var requestedVolume: Float = 0.8
    private var requestedSound: Int = ReedSound.musette.rawValue

    private var renderNotes = [Int](repeating: -1, count: voiceCount)
    private var held = [Bool](repeating: false, count: voiceCount)
    private var increments = [Float](repeating: 0, count: voiceCount * 3)
    private var voices: [Voice]
    private var pressure: Float = 0
    private var brightness: Float = 0.5
    private let sampleRate: Float
    private let attack: Float

    init(sampleRate: Float) {
        let rate = max(sampleRate, 8_000)
        self.sampleRate = rate
        voices = Array(repeating: Voice(), count: Self.voiceCount)
        attack = Float(1 - exp(-1 / Double(rate * 0.03)))
    }

    func setControls(
        notes: [Int],
        pressure: Float,
        brightness: Float,
        sustain: Float = 0.15,
        volume: Float = 1,
        sound: ReedSound = .musette
    ) {
        lock.lock()
        defer { lock.unlock() }
        for index in 0..<Self.voiceCount {
            requestedNotes[index] = index < notes.count ? notes[index] : -1
        }
        requestedPressure = min(1, max(0, pressure))
        requestedBrightness = min(1, max(0, brightness))
        requestedSustain = min(1, max(0, sustain))
        requestedVolume = min(1, max(0, volume))
        requestedSound = sound.rawValue
    }

    func renderMono(frameCount: Int) -> [Float] {
        var samples = [Float](repeating: 0, count: frameCount)
        samples.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            render(into: base, frameCount: frameCount)
        }
        return samples
    }

    func render(into buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard frameCount > 0 else { return }

        lock.lock()
        for index in 0..<Self.voiceCount {
            renderNotes[index] = requestedNotes[index]
        }
        let targetPressure = requestedPressure
        let targetBrightness = requestedBrightness
        let sustain = requestedSustain
        let volume = requestedVolume
        let sound = requestedSound
        lock.unlock()

        let recipe = ReedRecipe.all[min(max(0, sound), ReedRecipe.all.count - 1)]
        let lowAlpha = Float(1 - exp(-2 * Double.pi * Double(recipe.lowHz) / Double(sampleRate)))

        for index in 0..<Self.voiceCount {
            held[index] = false
        }
        for index in 0..<Self.voiceCount {
            let midi = renderNotes[index]
            guard midi >= 0 else { continue }
            guard let slot = claimSlot(for: midi) else { continue }
            held[slot] = true
        }

        for index in 0..<Self.voiceCount {
            let midi = voices[index].midi
            guard midi >= 0 else {
                increments[index * 3] = 0
                increments[index * 3 + 1] = 0
                increments[index * 3 + 2] = 0
                continue
            }
            let frequency = 440 * pow(2, (Float(midi) - 69) / 12)
            let step = frequency / sampleRate
            increments[index * 3] = step / recipe.detune
            increments[index * 3 + 1] = step
            increments[index * 3 + 2] = step * recipe.detune
        }

        let frames = Float(frameCount)
        let pressureStep = (targetPressure - pressure) / frames
        let brightnessStep = (targetBrightness - brightness) / frames
        let midPressure = (pressure + targetPressure) * 0.5
        let midBrightness = (brightness + targetBrightness) * 0.5
        let cutoff = (900 + midPressure * 2200 + midBrightness * 800) * recipe.cutoff
        let highAlpha = Float(1 - exp(-2 * Double.pi * Double(cutoff) / Double(sampleRate)))
        let releaseSeconds = Sustain.seconds(for: Double(sustain))
        let release = Float(1 - exp(-1 / (Double(sampleRate) * releaseSeconds)))

        for frame in 0..<frameCount {
            pressure += pressureStep
            brightness += brightnessStep
            var mix: Float = 0
            for index in 0..<Self.voiceCount {
                mix += sampleVoice(index, highAlpha: highAlpha, lowAlpha: lowAlpha, release: release, recipe: recipe)
            }
            buffer[frame] = tanh(mix * pressure * volume * 1.2)
        }
    }

    private func claimSlot(for midi: Int) -> Int? {
        if let existing = voices.firstIndex(where: { $0.midi == midi }) {
            return existing
        }
        if let free = voices.indices.first(where: { voices[$0].midi < 0 && !held[$0] }) {
            prepare(free, midi: midi)
            return free
        }
        var quietest: Int?
        var level = Float.greatestFiniteMagnitude
        for index in voices.indices where !held[index] && voices[index].env < level {
            level = voices[index].env
            quietest = index
        }
        if let quietest {
            prepare(quietest, midi: midi)
            return quietest
        }
        return nil
    }

    private func prepare(_ index: Int, midi: Int) {
        voices[index] = Voice()
        voices[index].midi = midi
    }

    private func sampleVoice(
        _ index: Int,
        highAlpha: Float,
        lowAlpha: Float,
        release: Float,
        recipe: ReedRecipe
    ) -> Float {
        let target: Float = held[index] ? 1 : 0
        let envelope = voices[index].env
        if envelope == 0, target == 0 {
            return 0
        }
        let coefficient = target > envelope ? attack : release
        let updated = envelope + (target - envelope) * coefficient
        voices[index].env = updated
        if updated < 0.0008, target == 0 {
            voices[index] = Voice()
            return 0
        }

        var phase0 = voices[index].phase0 + increments[index * 3]
        var phase1 = voices[index].phase1 + increments[index * 3 + 1]
        var phase2 = voices[index].phase2 + increments[index * 3 + 2]
        if phase0 >= 1 { phase0 -= 1 }
        if phase1 >= 1 { phase1 -= 1 }
        if phase2 >= 1 { phase2 -= 1 }
        voices[index].phase0 = phase0
        voices[index].phase1 = phase1
        voices[index].phase2 = phase2

        let raw = reed(phase0, recipe) * recipe.left
            + reed(phase1, recipe) * recipe.center
            + reed(phase2, recipe) * recipe.right
        var high = voices[index].highCut
        var low = voices[index].lowCut
        high += (raw - high) * highAlpha
        low += (raw - low) * lowAlpha
        voices[index].highCut = high
        voices[index].lowCut = low
        return (high - low) * updated
    }

    private func reed(_ phase: Float, _ recipe: ReedRecipe) -> Float {
        let angle = phase * (2 * Float.pi)
        return (
            sin(angle) * recipe.h1
                + sin(angle * 2) * recipe.h2
                + sin(angle * 3) * recipe.h3
                + sin(angle * 4) * recipe.h4
        ) * 0.42
    }
}

@MainActor
final class AccordionSynth {
    private let engine = AVAudioEngine()
    private var reed: ReedEngine?
    private var started = false

    func start() throws {
        guard !started else { return }
        let hardwareRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = hardwareRate > 0 ? hardwareRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw SynthError.formatUnavailable
        }
        let reed = ReedEngine(sampleRate: Float(sampleRate))
        let node = Self.makeSourceNode(format: format, reed: reed)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        self.reed = reed
        started = true
    }

    func setPerformance(
        notes: [Int],
        pressure: Float,
        brightness: Float,
        sustain: Float,
        volume: Float,
        sound: ReedSound
    ) {
        reed?.setControls(
            notes: notes,
            pressure: pressure,
            brightness: brightness,
            sustain: sustain,
            volume: volume,
            sound: sound
        )
    }

    func stop() {
        guard started else { return }
        engine.stop()
        started = false
    }

    nonisolated private static func makeSourceNode(format: AVAudioFormat, reed: ReedEngine) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let frames = Int(frameCount)
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let first = buffers.first?.mData else { return noErr }
            reed.render(into: first.assumingMemoryBound(to: Float.self), frameCount: frames)
            if buffers.count > 1 {
                let byteCount = frames * MemoryLayout<Float>.size
                for buffer in buffers.dropFirst() {
                    guard let destination = buffer.mData else { continue }
                    destination.copyMemory(from: first, byteCount: byteCount)
                }
            }
            return noErr
        }
    }
}

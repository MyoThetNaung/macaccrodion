import Foundation

enum AccordionSelfTest {
    static func run() -> Int {
        var failures = 0
        failures += sensor()
        failures += bellows()
        failures += synth()
        failures += chain()
        if failures == 0 {
            print("self-test passed")
        } else {
            print("self-test failed: \(failures)")
        }
        return failures
    }

    private static func sensor() -> Int {
        var failures = degreesSample() ? 0 : 1
        guard let angle = LidAngleSensor.readOnce() else {
            print("FAIL sensor unavailable")
            return failures + 1
        }
        guard (0...180).contains(angle) else {
            print("FAIL sensor \(angle)")
            return failures + 1
        }
        print(String(format: "ok sensor %.1f°", angle))
        let keys = AccordionKey.byCode
        let mapped = keys[12]?.midi(reversed: false) == 48 && keys[0]?.midi(reversed: false) == 60
            && keys[6]?.midi(reversed: false) == 72 && keys[32]?.midi(reversed: false) == 59
            && keys[38]?.midi(reversed: false) == 71 && keys[46]?.midi(reversed: false) == 83
        let flipped = keys[12]?.midi(reversed: true) == 59 && keys[12]?.note(reversed: true) == "B3"
            && keys[32]?.midi(reversed: true) == 48 && keys[46]?.midi(reversed: true) == 72
        if mapped, flipped, AccordionKey.rows.count == 3, keys.count == 21 {
            print("ok keys")
        } else {
            print("FAIL keys")
            failures += 1
        }
        return failures
    }

    private static func degreesSample() -> Bool {
        let straight = LidAngleSensor.degrees(from: [0, 90, 0, 0, 0, 0, 0, 0], count: 8)
        let wide = LidAngleSensor.degrees(from: [0, 0x0A, 0x00], count: 3)
        let tooFar = LidAngleSensor.degrees(from: [0, 0x00, 0x01], count: 3)
        let short = LidAngleSensor.degrees(from: [0, 1], count: 2)
        let ok = straight == 90 && wide == 10 && tooFar == nil && short == nil
        if ok {
            print("ok report-bytes")
        } else {
            print("FAIL report-bytes")
        }
        return ok
    }

    private static func bellows() -> Int {
        var failures = 0
        var bellows = Bellows()
        var time = 0.0
        var state = bellows.update(angle: 100, time: time)
        for _ in 0..<40 {
            time += 1.0 / 60.0
            state = bellows.update(angle: 100, time: time)
        }
        if state.pressure < 0.05, state.direction == .still {
            print("ok bellows-rest")
        } else {
            print("FAIL bellows-rest pressure \(state.pressure) direction \(state.direction)")
            failures += 1
        }

        var flicker = Bellows()
        time = 0
        var angle = 100.0
        var flickerState = flicker.update(angle: angle, time: time)
        for index in 0..<60 {
            time += 1.0 / 60.0
            angle = index.isMultiple(of: 2) ? 100 : 101
            flickerState = flicker.update(angle: angle, time: time)
        }
        if flickerState.pressure < 0.05 {
            print("ok bellows-flicker")
        } else {
            print("FAIL bellows-flicker pressure \(flickerState.pressure)")
            failures += 1
        }

        var moving = Bellows()
        time = 0
        angle = 80
        var movingState = moving.update(angle: angle, time: time)
        for _ in 0..<36 {
            time += 1.0 / 60.0
            angle += 0.5
            movingState = moving.update(angle: angle, time: time)
        }
        if movingState.direction == .pull, movingState.pressure > 0.2, movingState.brightness == 0 {
            print(String(format: "ok bellows-pull %.2f", movingState.pressure))
        } else {
            print("FAIL bellows-pull \(movingState)")
            failures += 1
        }

        for _ in 0..<36 {
            time += 1.0 / 60.0
            angle -= 0.8
            movingState = moving.update(angle: angle, time: time)
        }
        if movingState.direction == .push, movingState.pressure > 0.2, movingState.brightness == 1 {
            print(String(format: "ok bellows-push %.2f", movingState.pressure))
        } else {
            print("FAIL bellows-push \(movingState)")
            failures += 1
        }

        let rested = angle
        for _ in 0..<50 {
            time += 1.0 / 60.0
            movingState = moving.update(angle: rested, time: time)
        }
        if movingState.pressure < 0.05, movingState.direction == .still {
            print("ok bellows-decay")
        } else {
            print("FAIL bellows-decay pressure \(movingState.pressure)")
            failures += 1
        }

        let shortAir = restingPressure(sustain: 0)
        let longAir = restingPressure(sustain: 1)
        if longAir > shortAir + 0.2 {
            print(String(format: "ok sustain-air %.2f -> %.2f", shortAir, longAir))
        } else {
            print("FAIL sustain-air short \(shortAir) long \(longAir)")
            failures += 1
        }
        return failures
    }

    private static func restingPressure(sustain: Double) -> Double {
        var bellows = Bellows()
        bellows.sustain = sustain
        var time = 0.0
        var angle = 80.0
        var state = bellows.update(angle: angle, time: time)
        for _ in 0..<36 {
            time += 1.0 / 60.0
            angle += 0.8
            state = bellows.update(angle: angle, time: time)
        }
        for _ in 0..<18 {
            time += 1.0 / 60.0
            state = bellows.update(angle: angle, time: time)
        }
        return state.pressure
    }

    private static func synth() -> Int {
        var failures = 0
        let silentEngine = ReedEngine(sampleRate: 48_000)
        silentEngine.setControls(notes: [60], pressure: 0, brightness: 0.5)
        let silent = silentEngine.renderMono(frameCount: 12_000)
        if rms(silent) < 0.001, finite(silent) {
            print("ok synth-silence")
        } else {
            print("FAIL synth-silence rms \(rms(silent))")
            failures += 1
        }

        let tone = ReedEngine(sampleRate: 48_000)
        tone.setControls(notes: [60, 64, 67], pressure: 0.85, brightness: 1)
        let sounded = tone.renderMono(frameCount: 48_000)
        let level = rms(sounded)
        if level > 0.02, level < 0.75, finite(sounded) {
            print(String(format: "ok synth-tone %.3f", level))
        } else {
            print("FAIL synth-tone rms \(level)")
            failures += 1
        }

        let released = ReedEngine(sampleRate: 48_000)
        released.setControls(notes: [60], pressure: 0.8, brightness: 0.5)
        _ = released.renderMono(frameCount: 24_000)
        released.setControls(notes: [], pressure: 0.8, brightness: 0.5)
        let fading = released.renderMono(frameCount: 4_000)
        _ = released.renderMono(frameCount: 36_000)
        let tail = released.renderMono(frameCount: 4_000)
        if rms(fading) > rms(tail), rms(tail) < 0.001, finite(tail) {
            print("ok synth-release")
        } else {
            print("FAIL synth-release fade \(rms(fading)) tail \(rms(tail))")
            failures += 1
        }

        let shortTail = releaseTail(sustain: 0)
        let longTail = releaseTail(sustain: 1)
        if longTail > shortTail * 2 {
            print(String(format: "ok sustain %.4f -> %.4f", shortTail, longTail))
        } else {
            print("FAIL sustain short \(shortTail) long \(longTail)")
            failures += 1
        }
        return failures
    }

    private static func releaseTail(sustain: Float) -> Float {
        let engine = ReedEngine(sampleRate: 48_000)
        engine.setControls(notes: [60], pressure: 0.85, brightness: 0.5, sustain: sustain)
        _ = engine.renderMono(frameCount: 24_000)
        engine.setControls(notes: [], pressure: 0.85, brightness: 0.5, sustain: sustain)
        _ = engine.renderMono(frameCount: 8_000)
        return rms(engine.renderMono(frameCount: 8_000))
    }

    private static func chain() -> Int {
        var bellows = Bellows()
        var time = 0.0
        var angle = 90.0
        var state = bellows.update(angle: angle, time: time)
        for _ in 0..<20 {
            time += 1.0 / 60.0
            state = bellows.update(angle: angle, time: time)
        }
        let resting = ReedEngine(sampleRate: 48_000)
        resting.setControls(notes: [60], pressure: Float(state.pressure), brightness: Float(state.brightness))
        let quiet = resting.renderMono(frameCount: 8_000)
        guard rms(quiet) < 0.001 else {
            print("FAIL chain-rest rms \(rms(quiet))")
            return 1
        }
        print("ok chain-rest")

        for _ in 0..<40 {
            time += 1.0 / 60.0
            angle += 1.2
            state = bellows.update(angle: angle, time: time)
        }
        let playing = ReedEngine(sampleRate: 48_000)
        playing.setControls(notes: [62, 67], pressure: Float(state.pressure), brightness: Float(state.brightness))
        let loud = playing.renderMono(frameCount: 48_000)
        let level = rms(loud)
        if level > 0.02, finite(loud) {
            print(String(format: "ok chain-move %.3f pressure %.2f", level, state.pressure))
            return 0
        }
        print("FAIL chain-move rms \(level) pressure \(state.pressure)")
        return 1
    }

    private static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        return sqrt(sum / Float(samples.count))
    }

    private static func finite(_ samples: [Float]) -> Bool {
        samples.allSatisfy { $0.isFinite && abs($0) <= 1 }
    }
}

import AppKit
import Foundation

@MainActor
final class AccordionModel: ObservableObject {
    @Published private(set) var angle: Double = 0
    @Published private(set) var pressure: Double = 0
    @Published private(set) var direction: BellowsDirection = .still
    @Published private(set) var heldKeyCodes: Set<UInt16> = []
    @Published private(set) var reversedOctaves: Set<Int> = []
    @Published private(set) var sustain: Double = 0.15
    @Published private(set) var sensorAvailable = true
    @Published private(set) var message: String?

    private let sensor = LidAngleSensor()
    private var bellows = Bellows()
    private let synth = AccordionSynth()
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var heldNotes: [UInt16: Int] = [:]
    private var noteBuffer: [Int] = []
    private var started = false
    private var announcedSensor = false

    var sustainLabel: String {
        String(format: "%.1fs", Sustain.seconds(for: sustain))
    }

    var directionLabel: String {
        switch direction {
        case .still: "Still"
        case .push: "Push"
        case .pull: "Pull"
        }
    }

    func start() {
        guard !started else { return }
        started = true
        do {
            try synth.start()
        } catch {
            message = "Audio could not start."
        }
        sensor.setAngleHandler { [weak self] angle in
            Task { @MainActor in
                self?.ingest(angle: angle)
            }
        }
        sensor.setUnavailableHandler { [weak self] in
            Task { @MainActor in
                self?.sensorAvailable = false
                self?.message = "This Mac did not expose the lid angle sensor."
            }
        }
        sensor.start()
        installKeys()
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop()
            }
        }
        NSApplication.shared.activate()
        DispatchQueue.main.async {
            NSApplication.shared.windows.first?.makeKey()
        }
    }

    func stop() {
        sensor.stop()
        synth.stop()
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        started = false
    }

    private func ingest(angle: Double) {
        if !announcedSensor {
            announcedSensor = true
            fputs(String(format: "Lid angle sensor reading %.1f°\n", angle), stderr)
        }
        let state = bellows.update(angle: angle, time: ProcessInfo.processInfo.systemUptime)
        if self.angle != state.angle {
            self.angle = state.angle
        }
        if abs(self.pressure - state.pressure) > 0.004 {
            self.pressure = state.pressure
        }
        if self.direction != state.direction {
            self.direction = state.direction
        }
        pushSynth(pressure: state.pressure, brightness: state.brightness)
    }

    private func installKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            let type = event.type.rawValue
            let keyCode = event.keyCode
            let isRepeat = event.isARepeat
            let flags = event.modifierFlags.rawValue
            let consume = MainActor.assumeIsolated {
                self.handle(type: type, keyCode: keyCode, isRepeat: isRepeat, flags: flags)
            }
            return consume ? nil : event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.releaseAllKeys()
            }
        }
    }

    private func handle(type: UInt, keyCode: UInt16, isRepeat: Bool, flags: UInt) -> Bool {
        let modifiers = NSEvent.ModifierFlags(rawValue: flags)
        let eventType = NSEvent.EventType(rawValue: type)
        guard eventType == .keyDown || eventType == .keyUp else {
            return false
        }
        guard let key = AccordionKey.byCode[keyCode] else {
            return false
        }
        if modifiers.contains(.command) {
            return false
        }
        if eventType == .keyDown {
            if isRepeat {
                return true
            }
            heldNotes[keyCode] = soundingMidi(for: key)
            heldKeyCodes = Set(heldNotes.keys)
            pushSynth(pressure: pressure, brightness: bellows.state.brightness)
            return true
        }
        heldNotes.removeValue(forKey: keyCode)
        heldKeyCodes = Set(heldNotes.keys)
        pushSynth(pressure: pressure, brightness: bellows.state.brightness)
        return true
    }

    func isReversed(_ octave: Int) -> Bool {
        reversedOctaves.contains(octave)
    }

    func noteName(for key: AccordionKey) -> String {
        key.note(reversed: isReversed(key.octave))
    }

    func setSustain(_ value: Double) {
        sustain = min(1, max(0, value))
        bellows.sustain = sustain
        pushSynth(pressure: pressure, brightness: bellows.state.brightness)
    }

    func toggleOrder(octave: Int) {
        if reversedOctaves.contains(octave) {
            reversedOctaves.remove(octave)
        } else {
            reversedOctaves.insert(octave)
        }
        for code in heldNotes.keys {
            guard let key = AccordionKey.byCode[code] else { continue }
            heldNotes[code] = soundingMidi(for: key)
        }
        pushSynth(pressure: pressure, brightness: bellows.state.brightness)
    }

    private func soundingMidi(for key: AccordionKey) -> Int {
        key.midi(reversed: isReversed(key.octave))
    }

    private func releaseAllKeys() {
        guard !heldNotes.isEmpty else { return }
        heldNotes.removeAll(keepingCapacity: true)
        heldKeyCodes = []
        pushSynth(pressure: pressure, brightness: bellows.state.brightness)
    }

    private func pushSynth(pressure: Double, brightness: Double) {
        noteBuffer.removeAll(keepingCapacity: true)
        noteBuffer.append(contentsOf: heldNotes.values)
        synth.setPerformance(
            notes: noteBuffer,
            pressure: Float(pressure),
            brightness: Float(brightness),
            sustain: Float(sustain)
        )
    }
}

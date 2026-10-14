import Foundation
import IOKit
import IOKit.hid

/// Reads the MacBook lid angle from the built-in HID sensor.
/// Vendor 0x05AC, product 0x8104, usage page 0x20, usage 0x8A, feature report 1.
/// Degrees are the little-endian UInt16 in bytes 1 and 2.
final class LidAngleSensor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "accordion.lid-angle")
    private let lock = NSLock()
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var timer: DispatchSourceTimer?
    private var onAngle: (@Sendable (Double) -> Void)?
    private var onUnavailable: (@Sendable () -> Void)?
    private var running = false

    func setAngleHandler(_ handler: @escaping @Sendable (Double) -> Void) {
        lock.lock()
        onAngle = handler
        lock.unlock()
    }

    func setUnavailableHandler(_ handler: @escaping @Sendable () -> Void) {
        lock.lock()
        onUnavailable = handler
        lock.unlock()
    }

    func start() {
        queue.async { [weak self] in
            self?.startOnQueue()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopOnQueue()
        }
    }

    static func readOnce() -> Double? {
        guard let opened = openSensor() else { return nil }
        defer { close(opened) }
        return readDegrees(from: opened.device)
    }

    static func degrees(from bytes: [UInt8], count: Int) -> Double? {
        guard count >= 3, bytes.count >= 3 else { return nil }
        let value = Int(bytes[1]) | (Int(bytes[2]) << 8)
        let degrees = Double(value)
        guard (0...200).contains(degrees) else { return nil }
        return degrees
    }

    private func startOnQueue() {
        guard !running else { return }
        guard let opened = Self.openSensor() else {
            emitUnavailable()
            return
        }
        manager = opened.manager
        device = opened.device
        running = true

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 60.0, leeway: .milliseconds(4))
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        timer.resume()
        self.timer = timer
        if let angle = Self.readDegrees(from: opened.device) {
            emit(angle)
        }
    }

    private func stopOnQueue() {
        timer?.cancel()
        timer = nil
        if let manager, let device {
            Self.close(OpenedSensor(manager: manager, device: device))
        }
        manager = nil
        device = nil
        running = false
    }

    private func poll() {
        guard let device else { return }
        guard let angle = Self.readDegrees(from: device) else { return }
        emit(angle)
    }

    private func emit(_ angle: Double) {
        lock.lock()
        let handler = onAngle
        lock.unlock()
        handler?(angle)
    }

    private func emitUnavailable() {
        lock.lock()
        let handler = onUnavailable
        lock.unlock()
        handler?()
    }

    private struct OpenedSensor {
        let manager: IOHIDManager
        let device: IOHIDDevice
    }

    private static func sensorMatchers() -> [[String: Any]] {
        [
        [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDProductIDKey: 0x8104,
            kIOHIDDeviceUsagePageKey: 0x0020,
            kIOHIDDeviceUsageKey: 0x008A,
        ],
        [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDProductIDKey: 0x8104,
            kIOHIDPrimaryUsagePageKey: 0x0020,
            kIOHIDPrimaryUsageKey: 0x008A,
        ],
        [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDProductIDKey: 0x8104,
        ],
        ]
    }

    private static func openSensor() -> OpenedSensor? {
        for matching in sensorMatchers() {
            let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
            guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
                continue
            }
            let devices = copyDevices(from: manager)
            var closedReading: OpenedSensor?
            var found = false
            for device in devices {
                _ = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
                guard let degrees = readDegrees(from: device) else {
                    IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
                    continue
                }
                let opened = OpenedSensor(manager: manager, device: device)
                if degrees > 0 {
                    if let closedReading {
                        IOHIDDeviceClose(closedReading.device, IOOptionBits(kIOHIDOptionsTypeNone))
                    }
                    return opened
                }
                if closedReading == nil {
                    closedReading = opened
                } else {
                    IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
                }
                found = true
            }
            if let closedReading, found {
                return closedReading
            }
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        return nil
    }

    private static func close(_ opened: OpenedSensor) {
        IOHIDDeviceClose(opened.device, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerClose(opened.manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private static func copyDevices(from manager: IOHIDManager) -> [IOHIDDevice] {
        guard let raw = IOHIDManagerCopyDevices(manager) else { return [] }
        let set = raw as NSSet
        var devices: [IOHIDDevice] = []
        for case let device as IOHIDDevice in set {
            devices.append(device)
        }
        return devices
    }

    private static func readDegrees(from device: IOHIDDevice) -> Double? {
        var bytes = [UInt8](repeating: 0, count: 8)
        var count = CFIndex(bytes.count)
        let result = bytes.withUnsafeMutableBufferPointer { buffer -> IOReturn in
            guard let base = buffer.baseAddress else { return kIOReturnError }
            return IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, base, &count)
        }
        guard result == kIOReturnSuccess else { return nil }
        return degrees(from: bytes, count: Int(count))
    }
}

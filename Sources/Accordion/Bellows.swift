import Foundation

enum BellowsDirection: Equatable {
    case still
    case push
    case pull
}

struct BellowsState: Equatable {
    var angle: Double
    var pressure: Double
    var speed: Double
    var direction: BellowsDirection
    var brightness: Double
}

/// Turns lid angle into airflow. Sound follows how fast the lid moves, not how far it is open.
struct Bellows {
    private(set) var state = BellowsState(
        angle: 0,
        pressure: 0,
        speed: 0,
        direction: .still,
        brightness: 0.5
    )

    private var history: [(time: Double, angle: Double)] = []
    private let window: Double = 0.12
    private let deadzone = 12.0
    private let fullScale = 80.0
    private let response: Double = 0.10

    mutating func update(angle: Double, time: Double) -> BellowsState {
        if let last = history.last {
            if time <= last.time {
                return state
            }
            let step = abs(angle - last.angle)
            if step > 40 {
                return state
            }
        }

        history.append((time, angle))
        let oldest = time - window
        while history.count > 2, history[0].time < oldest {
            history.removeFirst()
        }

        let speed: Double
        if let first = history.first, history.count >= 2, time > first.time {
            speed = (angle - first.angle) / (time - first.time)
        } else {
            speed = 0
        }

        let magnitude = abs(speed)
        let excess = max(0, magnitude - deadzone)
        var target = min(1, excess / fullScale)
        target = pow(target, 0.7)

        let dt: Double
        if history.count >= 2 {
            dt = time - history[history.count - 2].time
        } else {
            dt = 1.0 / 60.0
        }
        let alpha = 1 - exp(-max(dt, 0.001) / response)
        var pressure = state.pressure + (target - state.pressure) * alpha
        if target == 0, pressure < 0.015 {
            pressure = 0
        }

        var brightness = state.brightness
        let direction: BellowsDirection
        if magnitude < deadzone {
            direction = .still
        } else if speed > 0 {
            direction = .pull
            brightness = 0
        } else {
            direction = .push
            brightness = 1
        }

        state = BellowsState(
            angle: angle,
            pressure: pressure,
            speed: speed,
            direction: direction,
            brightness: brightness
        )
        return state
    }
}

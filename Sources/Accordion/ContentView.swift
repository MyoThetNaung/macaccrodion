import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AccordionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            BellowsGraphic(
                angle: model.angle,
                pressure: model.pressure,
                direction: model.direction
            )
            .frame(height: 168)
            airMeter
            sustainSlider
            keys
            instruction
        }
        .padding(28)
        .frame(minWidth: 820, minHeight: 740)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(background)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Accordion")
                .font(.system(size: 34, weight: .medium, design: .serif))
                .foregroundStyle(Lacquer.pearl)
                .shadow(color: .white.opacity(0.18), radius: 0, y: 1)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if model.sensorAvailable {
                    Text("\(Int(model.angle.rounded()))°  \(model.directionLabel)")
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(model.direction == .still ? Lacquer.silver : Lacquer.pearl)
                } else {
                    Text("No lid sensor")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(Lacquer.silver)
                }
            }
        }
    }

    private var airMeter: some View {
        HStack(spacing: 12) {
            Text("Air")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(Lacquer.silver)
                .frame(width: 32, alignment: .leading)
            GeometryReader { geometry in
                let width = geometry.size.width * CGFloat(min(1, max(0, model.pressure)))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.55))
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Lacquer.silver, Color(white: 0.55)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: width)
                        .shadow(color: .white.opacity(0.35), radius: 3, y: 0)
                }
            }
            .frame(height: 16)
        }
    }

    private var sustainSlider: some View {
        HStack(spacing: 12) {
            Text("Sustain")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(Lacquer.silver)
                .frame(width: 64, alignment: .leading)
            Slider(
                value: Binding(
                    get: { model.sustain },
                    set: { model.setSustain($0) }
                ),
                in: 0...1
            )
            .tint(Lacquer.pearl)
            .accessibilityLabel("Sustain")
            Text(model.sustainLabel)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Lacquer.silver)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var keys: some View {
        VStack(spacing: 8) {
            ForEach(AccordionKey.rows, id: \.first?.id) { row in
                let octave = row.first?.octave ?? 0
                let reversed = model.isReversed(octave)
                HStack(spacing: 8) {
                    OrderButton(octave: octave, reversed: reversed) {
                        model.toggleOrder(octave: octave)
                    }
                    ForEach(row) { key in
                        let held = model.heldKeyCodes.contains(key.id)
                        KeyCap(
                            letter: key.letter,
                            note: model.noteName(for: key),
                            held: held,
                            pressure: model.pressure
                        )
                    }
                }
            }
        }
    }

    private var instruction: some View {
        Text(model.message ?? "Hold a key, then open or close the lid. Each octave button flips that row so the notes sit on closer keys.")
            .font(.system(size: 15, weight: .regular, design: .serif))
            .foregroundStyle(Lacquer.silver.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.16), Color(white: 0.05), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.white.opacity(0.14), Color.clear],
                center: .top,
                startRadius: 20,
                endRadius: 520
            )
        }
    }
}

private enum Lacquer {
    static let pearl = Color(white: 0.95)
    static let silver = Color(white: 0.72)
    static let ink = Color(white: 0.12)
    static let ivoryTop = Color(white: 0.98)
    static let ivoryMid = Color(white: 0.86)
    static let ivoryStain = Color(white: 0.70)
    static let edge = Color(white: 0.42)
}

private struct OrderButton: View {
    let octave: Int
    let reversed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("Oct \(octave)")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                Text(reversed ? "Reverse" : "Normal")
                    .font(.system(size: 13, weight: .bold, design: .serif))
            }
        }
        .buttonStyle(LacquerButtonStyle(dark: reversed))
        .frame(width: 78)
        .accessibilityLabel("Octave \(octave) \(reversed ? "reverse" : "normal") order")
    }
}

private struct LacquerButtonStyle: ButtonStyle {
    var dark: Bool

    func makeBody(configuration: Configuration) -> some View {
        LacquerPlate(pressed: configuration.isPressed, dark: dark) {
            configuration.label
                .foregroundStyle(dark ? Lacquer.pearl : Lacquer.ink)
        }
    }
}

private struct KeyCap: View {
    let letter: String
    let note: String
    let held: Bool
    let pressure: Double

    var body: some View {
        LacquerPlate(pressed: held, dark: false) {
            VStack(spacing: 4) {
                HStack {
                    Text(letter)
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundStyle(Lacquer.ink.opacity(0.45))
                    Spacer()
                    Circle()
                        .fill(Color.white)
                        .frame(width: 7, height: 7)
                        .shadow(color: .white.opacity(held ? 0.9 : 0), radius: 4)
                        .opacity(held ? 0.45 + pressure * 0.55 : 0.18)
                }
                Spacer(minLength: 0)
                Text(note)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Lacquer.ink)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(letter) plays \(note)")
        .accessibilityAddTraits(held ? .isSelected : [])
    }
}

private struct LacquerPlate<Content: View>: View {
    var pressed: Bool
    var dark: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.28), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .offset(y: 5)

            content()
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .background(face)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(pressed ? 0.12 : 0.55), lineWidth: 1)
                )
                .shadow(color: .white.opacity(pressed ? 0.05 : 0.28), radius: pressed ? 1 : 3, y: pressed ? 0 : -1)
                .offset(y: pressed ? 4 : 0)
        }
        .frame(height: 72, alignment: .top)
        .shadow(color: .black.opacity(pressed ? 0.35 : 0.65), radius: pressed ? 2 : 7, y: pressed ? 1 : 5)
        .animation(.easeOut(duration: 0.07), value: pressed)
    }

    private var face: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(base)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(stain)
            LinearGradient(
                colors: [
                    Color.white.opacity(pressed ? 0.18 : 0.75),
                    Color.white.opacity(pressed ? 0.02 : 0.08),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .center
            )
            VStack {
                Capsule()
                    .fill(Color.white.opacity(pressed ? 0.2 : 0.85))
                    .frame(height: 3)
                    .padding(.horizontal, 10)
                    .padding(.top, 5)
                Spacer()
            }
        }
    }

    private var base: LinearGradient {
        if dark {
            return LinearGradient(
                colors: pressed
                    ? [Color(white: 0.16), Color(white: 0.05)]
                    : [Color(white: 0.28), Color(white: 0.08), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: pressed
                ? [Lacquer.ivoryMid, Lacquer.ivoryStain, Color(white: 0.62)]
                : [Lacquer.ivoryTop, Lacquer.ivoryMid, Lacquer.ivoryStain, Color(white: 0.93)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var stain: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(dark ? 0.15 : 0.02),
                Color.clear,
                Color.black.opacity(dark ? 0.35 : 0.10),
                Color.clear,
                Color.black.opacity(0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct BellowsGraphic: View {
    var angle: Double
    var pressure: Double
    var direction: BellowsDirection

    var body: some View {
        Canvas { context, size in
            let open = min(1, max(0, angle / 135))
            let motion: CGFloat
            switch direction {
            case .push:
                motion = -CGFloat(pressure) * 0.07
            case .pull:
                motion = CGFloat(pressure) * 0.045
            case .still:
                motion = 0
            }
            let travel = min(1, max(0.38, 0.42 + 0.56 * open + motion))
            let instrumentWidth = size.width * travel
            let originX = (size.width - instrumentWidth) / 2
            let capWidth = min(78, instrumentWidth * 0.16)
            let height = size.height * 0.70
            let top = (size.height - height) / 2
            let bottom = top + height
            let capTop = top - 18
            let capHeight = height + 36

            let leftCap = CGRect(x: originX, y: capTop, width: capWidth, height: capHeight)
            let rightCap = CGRect(x: originX + instrumentWidth - capWidth, y: capTop, width: capWidth, height: capHeight)
            fillCap(context, rect: leftCap)
            fillCap(context, rect: rightCap)

            let foldsLeft = leftCap.maxX - 2
            let foldsRight = rightCap.minX + 2
            let span = max(8, foldsRight - foldsLeft)
            let foldCount = 16
            let black = Color(white: 0.05)
            let pearl = Color(white: 0.92)
            let shadow = Color(white: 0.28)

            let backing = Path(roundedRect: CGRect(x: foldsLeft, y: top, width: span, height: height), cornerRadius: 2)
            context.fill(backing, with: .color(Color.black))

            for index in 0..<foldCount {
                let x0 = foldsLeft + span * CGFloat(index) / CGFloat(foldCount)
                let x1 = foldsLeft + span * CGFloat(index + 1) / CGFloat(foldCount)
                let mid = (x0 + x1) / 2
                var pleat = Path()
                let pointsUp = index.isMultiple(of: 2)
                if pointsUp {
                    pleat.move(to: CGPoint(x: x0, y: top))
                    pleat.addLine(to: CGPoint(x: x1, y: top))
                    pleat.addLine(to: CGPoint(x: mid, y: bottom))
                } else {
                    pleat.move(to: CGPoint(x: x0, y: bottom))
                    pleat.addLine(to: CGPoint(x: x1, y: bottom))
                    pleat.addLine(to: CGPoint(x: mid, y: top))
                }
                pleat.closeSubpath()
                context.fill(pleat, with: .color(pointsUp ? black : pearl))
                if !pointsUp {
                    var shine = Path()
                    shine.move(to: CGPoint(x: x0 + 1, y: bottom - 2))
                    shine.addLine(to: CGPoint(x: mid, y: top + 8))
                    shine.addLine(to: CGPoint(x: x1 - 1, y: bottom - 2))
                    context.stroke(shine, with: .color(Color.white.opacity(0.55)), lineWidth: 1)
                } else {
                    context.fill(pleat, with: .color(shadow.opacity(0.25)))
                }
            }

            if pressure > 0.03 {
                let glow = CGRect(x: foldsLeft, y: top, width: span, height: height)
                context.fill(
                    Path(glow),
                    with: .color(Color.white.opacity(0.14 * pressure))
                )
            }
        }
        .accessibilityLabel("Bellows")
    }

    private func fillCap(_ context: GraphicsContext, rect: CGRect) {
        let shape = Path(roundedRect: rect, cornerRadius: 10)
        context.fill(
            shape,
            with: .linearGradient(
                Gradient(colors: [Color(white: 0.30), Color(white: 0.08), Color.black]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
        let inset = rect.insetBy(dx: 7, dy: 8)
        context.stroke(
            Path(roundedRect: inset, cornerRadius: 7),
            with: .color(Color(white: 0.78)),
            lineWidth: 1.5
        )
        var highlight = Path()
        highlight.move(to: CGPoint(x: rect.minX + 12, y: rect.minY + 8))
        highlight.addLine(to: CGPoint(x: rect.maxX - 12, y: rect.minY + 8))
        context.stroke(highlight, with: .color(Color.white.opacity(0.45)), lineWidth: 2)
    }
}

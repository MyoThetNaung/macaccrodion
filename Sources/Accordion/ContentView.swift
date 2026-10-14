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
            keys
            instruction
        }
        .padding(28)
        .frame(minWidth: 820, minHeight: 700)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(background)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Accordion")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(ivory)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if model.sensorAvailable {
                    Text("\(Int(model.angle.rounded()))°  \(model.directionLabel)")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(model.direction == .still ? ivory.opacity(0.72) : gold)
                } else {
                    Text("No lid sensor")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(gold)
                }
            }
        }
    }

    private var airMeter: some View {
        HStack(spacing: 12) {
            Text("Air")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ivory.opacity(0.8))
                .frame(width: 32, alignment: .leading)
            GeometryReader { geometry in
                let width = geometry.size.width * CGFloat(min(1, max(0, model.pressure)))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [gold.opacity(0.75), Color(red: 0.95, green: 0.46, blue: 0.22)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width)
                }
            }
            .frame(height: 16)
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
            .font(.system(size: 15, weight: .regular, design: .rounded))
            .foregroundStyle(ivory.opacity(0.82))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.32, green: 0.08, blue: 0.09),
                Color(red: 0.13, green: 0.045, blue: 0.05),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var ivory: Color {
        Color(red: 0.97, green: 0.93, blue: 0.84)
    }

    private var gold: Color {
        Color(red: 0.93, green: 0.74, blue: 0.42)
    }
}

private struct OrderButton: View {
    let octave: Int
    let reversed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("Oct \(octave)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(reversed ? "Reverse" : "Normal")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(reversed ? Color(red: 0.22, green: 0.09, blue: 0.08) : Color(red: 0.97, green: 0.93, blue: 0.84))
            .frame(width: 78, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(reversed ? Color(red: 0.93, green: 0.74, blue: 0.42) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.93, green: 0.74, blue: 0.42).opacity(reversed ? 0 : 0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Octave \(octave) \(reversed ? "reverse" : "normal") order")
    }
}

private struct KeyCap: View {
    let letter: String
    let note: String
    let held: Bool
    let pressure: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(letter)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.55))
                Spacer()
                Circle()
                    .fill(Color(red: 0.85, green: 0.28, blue: 0.12))
                    .frame(width: 8, height: 8)
                    .opacity(held ? 0.35 + pressure * 0.65 : 0)
            }
            Spacer()
            Text(note)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(held ? Color(red: 0.96, green: 0.78, blue: 0.46) : Color(red: 0.96, green: 0.93, blue: 0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(held ? 0.18 : 0.28), lineWidth: 1)
        )
        .shadow(color: .black.opacity(held ? 0.08 : 0.28), radius: held ? 1 : 5, y: held ? 1 : 4)
        .offset(y: held ? 3 : 0)
        .animation(.easeOut(duration: 0.08), value: held)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(letter) plays \(note)")
        .accessibilityAddTraits(held ? .isSelected : [])
    }

    private var ink: Color {
        Color(red: 0.22, green: 0.09, blue: 0.08)
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

            let body = Color(red: 0.62, green: 0.10, blue: 0.13)
            let trim = Color(red: 0.86, green: 0.72, blue: 0.40)
            let leftCap = CGRect(x: originX, y: capTop, width: capWidth, height: capHeight)
            let rightCap = CGRect(x: originX + instrumentWidth - capWidth, y: capTop, width: capWidth, height: capHeight)
            fillCap(context, rect: leftCap, body: body, trim: trim)
            fillCap(context, rect: rightCap, body: body, trim: trim)

            let foldsLeft = leftCap.maxX - 2
            let foldsRight = rightCap.minX + 2
            let span = max(8, foldsRight - foldsLeft)
            let foldCount = 16
            let black = Color(red: 0.07, green: 0.05, blue: 0.05)
            let cream = Color(red: 0.95, green: 0.90, blue: 0.78)
            let seam = Color(red: 0.45, green: 0.07, blue: 0.08)

            let backing = Path(roundedRect: CGRect(x: foldsLeft, y: top, width: span, height: height), cornerRadius: 2)
            context.fill(backing, with: .color(seam))

            for index in 0..<foldCount {
                let x0 = foldsLeft + span * CGFloat(index) / CGFloat(foldCount)
                let x1 = foldsLeft + span * CGFloat(index + 1) / CGFloat(foldCount)
                let mid = (x0 + x1) / 2
                var pleat = Path()
                if index.isMultiple(of: 2) {
                    pleat.move(to: CGPoint(x: x0, y: top))
                    pleat.addLine(to: CGPoint(x: x1, y: top))
                    pleat.addLine(to: CGPoint(x: mid, y: bottom))
                } else {
                    pleat.move(to: CGPoint(x: x0, y: bottom))
                    pleat.addLine(to: CGPoint(x: x1, y: bottom))
                    pleat.addLine(to: CGPoint(x: mid, y: top))
                }
                pleat.closeSubpath()
                let fill = index.isMultiple(of: 2) ? black : cream
                context.fill(pleat, with: .color(fill))
            }

            if pressure > 0.03 {
                let glow = CGRect(x: foldsLeft, y: top, width: span, height: height)
                context.fill(
                    Path(glow),
                    with: .color(Color(red: 1, green: 0.72, blue: 0.32).opacity(0.16 * pressure))
                )
            }
        }
        .accessibilityLabel("Bellows")
    }

    private func fillCap(_ context: GraphicsContext, rect: CGRect, body: Color, trim: Color) {
        let shape = Path(roundedRect: rect, cornerRadius: 10)
        context.fill(shape, with: .color(body))
        let inset = rect.insetBy(dx: 7, dy: 8)
        context.stroke(Path(roundedRect: inset, cornerRadius: 7), with: .color(trim), lineWidth: 2)
    }
}

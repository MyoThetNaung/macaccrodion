import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AccordionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            BellowsGraphic(
                angle: model.angle,
                pressure: model.pressure,
                direction: model.direction
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 210)
            airMeter
            sustainSlider
            keys
            instruction
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(stainedPlate)
        .padding(12)
        .frame(minWidth: 860)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Accordion")
                .font(.custom("Snell Roundhand", size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.93, blue: 0.62),
                            Color(red: 0.86, green: 0.66, blue: 0.22),
                            Color(red: 0.62, green: 0.44, blue: 0.12),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if model.sensorAvailable {
                    Text("\(Int(model.angle.rounded()))°  \(model.directionLabel)")
                        .font(.custom("Times New Roman", size: 22))
                        .monospacedDigit()
                        .foregroundStyle(model.direction == .still ? Color.white.opacity(0.62) : Color.white)
                } else {
                    Text("No lid sensor")
                        .font(.custom("Times New Roman", size: 18))
                        .foregroundStyle(Color.white)
                }
            }
        }
    }

    private var airMeter: some View {
        HStack(spacing: 12) {
            Text("Air")
                .font(.custom("Times New Roman", size: 15).weight(.bold))
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
                .font(.custom("Times New Roman", size: 15).weight(.bold))
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
                .font(.custom("Times New Roman", size: 15))
                .monospacedDigit()
                .foregroundStyle(Lacquer.silver)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var keys: some View {
        VStack(spacing: 8) {
            ForEach(Array(AccordionKey.rows.enumerated()), id: \.element.first?.id) { rowIndex, row in
                let octave = row.first?.octave ?? 0
                let reversed = model.isReversed(octave)
                HStack(spacing: 16) {
                    OrderButton(octave: octave, reversed: reversed) {
                        model.toggleOrder(octave: octave)
                    }
                    HStack(spacing: 8) {
                        ForEach(row) { key in
                            let held = model.heldKeyCodes.contains(key.id)
                            RoundKey(
                                letter: key.letter,
                                note: model.noteName(for: key),
                                held: held,
                                pressure: model.pressure
                            )
                        }
                    }
                    .padding(.leading, rowIndex.isMultiple(of: 2) ? 0 : 29)
                    .padding(.trailing, rowIndex.isMultiple(of: 2) ? 29 : 0)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity)
        .background(buttonBoard)
    }

    private var buttonBoard: some View {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.16), Color(white: 0.05), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 10)
                    .padding(.horizontal, 48)
                    .padding(.top, 8)
                    .blur(radius: 1)
            }
            .shadow(color: .black.opacity(0.55), radius: 16, y: 8)
    }

    private var instruction: some View {
        Text(model.message ?? "Hold a key, then open or close the lid. Each octave button flips that row so the notes sit on closer keys.")
            .font(.custom("Times New Roman", size: 16))
            .foregroundStyle(Lacquer.silver.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stainedPlate: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.42), Color(white: 0.12), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.11),
                            Color(white: 0.045),
                            Color(white: 0.02),
                            Color.black,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(9)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.08), location: 0),
                            .init(color: Color.clear, location: 0.2),
                            .init(color: Color.white.opacity(0.04), location: 0.42),
                            .init(color: Color.clear, location: 0.6),
                            .init(color: Color.black.opacity(0.4), location: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(9)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.18), Color.clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 340
                    )
                )
                .frame(height: 120)
                .padding(.horizontal, 40)
                .offset(y: -310)
                .blur(radius: 4)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.9), lineWidth: 3)
                .padding(9)
        }
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: .black.opacity(0.9), radius: 16, y: 10)
    }
}

private enum Lacquer {
    static let pearl = Color(white: 0.95)
    static let silver = Color(white: 0.72)
    static let ink = Color(white: 0.14)
}

private struct OrderButton: View {
    let octave: Int
    let reversed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundFace(pressed: false, dark: !reversed) {
                VStack(spacing: 1) {
                    Text("\(octave)")
                        .font(.custom("Times New Roman", size: 16).weight(.bold))
                    Text(reversed ? "Rev" : "Norm")
                        .font(.custom("Times New Roman", size: 8).weight(.bold))
                }
                .foregroundStyle(reversed ? Lacquer.ink : Color.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Octave \(octave) \(reversed ? "reverse" : "normal") order")
    }
}

private struct RoundKey: View {
    let letter: String
    let note: String
    let held: Bool
    let pressure: Double

    var body: some View {
        VStack(spacing: 3) {
            RoundFace(pressed: held, dark: false) {
                VStack(spacing: 2) {
                    Text(note)
                        .font(.custom("Times New Roman", size: 12).weight(.bold))
                        .foregroundStyle(Lacquer.ink)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                        .shadow(color: .white.opacity(held ? 0.9 : 0), radius: 3)
                        .opacity(held ? 0.4 + pressure * 0.6 : 0.2)
                }
            }
            Text(letter)
                .font(.custom("Times New Roman", size: 9).weight(.bold))
                .foregroundStyle(Color.white.opacity(0.88))
                .frame(width: 54)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(letter) plays \(note)")
        .accessibilityAddTraits(held ? .isSelected : [])
    }
}

private struct RoundFace<Content: View>: View {
    var pressed: Bool
    var dark: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.22), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 52, height: 52)
                .offset(y: 4)

            content()
                .frame(width: 50, height: 50)
                .background(face)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(pressed ? 0.2 : 0.72), lineWidth: 1))
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(pressed ? 0.22 : 0.9))
                        .frame(width: 22, height: 7)
                        .padding(.top, 6)
                }
                .shadow(color: .white.opacity(pressed ? 0.04 : 0.28), radius: 2, y: -1)
                .offset(y: pressed ? 3 : 0)
        }
        .frame(width: 54, height: 58)
        .shadow(color: .black.opacity(pressed ? 0.35 : 0.6), radius: pressed ? 2 : 5, y: pressed ? 1 : 4)
        .animation(.easeOut(duration: 0.07), value: pressed)
    }

    private var face: some View {
        ZStack {
            Circle().fill(base)
            Circle().fill(
                RadialGradient(
                    colors: [Color.white.opacity(dark ? 0.08 : 0.45), Color.clear],
                    center: UnitPoint(x: 0.35, y: 0.28),
                    startRadius: 1,
                    endRadius: 28
                )
            )
            Circle().fill(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(dark ? 0.45 : 0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var base: LinearGradient {
        if dark {
            return LinearGradient(
                colors: [Color(white: 0.34), Color(white: 0.12), Color(white: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: pressed
                ? [Color(white: 0.78), Color(white: 0.62), Color(white: 0.7)]
                : [Color.white, Color(white: 0.9), Color(white: 0.74), Color(white: 0.96)],
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
            let squeeze: CGFloat
            switch direction {
            case .push:
                squeeze = CGFloat(pressure) * 0.09
            case .pull:
                squeeze = -CGFloat(pressure) * 0.05
            case .still:
                squeeze = 0
            }
            let reach = min(0.98, max(0.36, 0.38 + 0.60 * open - squeeze))
            let margin: CGFloat = 4
            let available = size.width - margin * 2
            let span = available * reach
            let origin = margin + (available - span) / 2
            let capWidth = min(46, span * 0.11)
            let top = size.height * 0.16
            let bottom = size.height * 0.84
            let puff = 14 + CGFloat(pressure) * 10

            let capTop = max(1, top - 10)
            let capHeight = min(size.height - 2, bottom + 10) - capTop
            let leftCap = CGRect(x: origin, y: capTop, width: capWidth, height: capHeight)
            let rightCap = CGRect(x: origin + span - capWidth, y: capTop, width: capWidth, height: capHeight)
            drawCap(context, rect: leftCap)
            drawCap(context, rect: rightCap)

            let foldStart = leftCap.maxX - 1
            let foldEnd = rightCap.minX + 1
            let foldCount = 24
            let foldWidth = max(2, (foldEnd - foldStart) / CGFloat(foldCount))
            var topEdge = Path()
            var bottomEdge = Path()
            topEdge.move(to: CGPoint(x: foldStart, y: top))
            bottomEdge.move(to: CGPoint(x: foldStart, y: bottom))

            for index in 0..<foldCount {
                let start = foldStart + foldWidth * CGFloat(index)
                let end = start + foldWidth
                let ridge = (start + end) / 2
                let tuck = min(puff, foldWidth * 0.46)
                let shadow = index.isMultiple(of: 2) ? 0.10 : 0.18
                let light = shadow + 0.10

                var nearFace = Path()
                nearFace.move(to: CGPoint(x: start, y: top))
                nearFace.addLine(to: CGPoint(x: ridge, y: top + tuck))
                nearFace.addLine(to: CGPoint(x: ridge, y: bottom - tuck))
                nearFace.addLine(to: CGPoint(x: start, y: bottom))
                nearFace.closeSubpath()
                context.fill(nearFace, with: .color(Color(white: shadow)))

                var farFace = Path()
                farFace.move(to: CGPoint(x: ridge, y: top + tuck))
                farFace.addLine(to: CGPoint(x: end, y: top))
                farFace.addLine(to: CGPoint(x: end, y: bottom))
                farFace.addLine(to: CGPoint(x: ridge, y: bottom - tuck))
                farFace.closeSubpath()
                context.fill(farFace, with: .color(Color(white: light)))

                topEdge.addLine(to: CGPoint(x: ridge, y: top + tuck))
                topEdge.addLine(to: CGPoint(x: end, y: top))
                bottomEdge.addLine(to: CGPoint(x: ridge, y: bottom - tuck))
                bottomEdge.addLine(to: CGPoint(x: end, y: bottom))

                var crease = Path()
                crease.move(to: CGPoint(x: ridge, y: top + tuck * 0.55))
                crease.addLine(to: CGPoint(x: ridge, y: bottom - tuck * 0.55))
                context.stroke(crease, with: .color(Color.white.opacity(0.28)), lineWidth: 1)
            }

            context.stroke(topEdge, with: .color(Color.white.opacity(0.55)), lineWidth: 1.4)
            context.stroke(bottomEdge, with: .color(Color.white.opacity(0.28)), lineWidth: 1.2)
        }
        .accessibilityLabel("Bellows")
    }

    private func drawCap(_ context: GraphicsContext, rect: CGRect) {
        let plate = Path(roundedRect: rect, cornerRadius: 8)
        context.fill(
            plate,
            with: .linearGradient(
                Gradient(colors: [Color(white: 0.34), Color(white: 0.08), Color.black]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
        context.stroke(
            Path(roundedRect: rect.insetBy(dx: 5, dy: 6), cornerRadius: 5),
            with: .color(Color(white: 0.78).opacity(0.85)),
            lineWidth: 1.2
        )
        var gleam = Path()
        gleam.move(to: CGPoint(x: rect.minX + 8, y: rect.minY + 6))
        gleam.addLine(to: CGPoint(x: rect.maxX - 8, y: rect.minY + 6))
        context.stroke(gleam, with: .color(Color.white.opacity(0.4)), lineWidth: 1.5)
    }
}

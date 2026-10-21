import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AccordionModel
    @State private var showGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let message = model.message {
                Text(message)
                    .font(.custom("Times New Roman", size: 15))
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.45))
            }
            BellowsGraphic(
                angle: model.angle,
                pressure: model.pressure,
                direction: model.direction
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 210, maxHeight: 300)
            airMeter
            sustainSlider
            volumeSlider
            soundPicker
            keys
        }
        .overlay(alignment: .bottomTrailing) {
            TeamCredit(moving: model.direction != .still, pressure: model.pressure)
                .padding(.trailing, 28)
                .padding(.bottom, 14)
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
        HStack(alignment: .center, spacing: 12) {
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
            helpButton
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
                .frame(width: 72, alignment: .leading)
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

    private var volumeSlider: some View {
        HStack(spacing: 12) {
            Text("Volume")
                .font(.custom("Times New Roman", size: 15).weight(.bold))
                .foregroundStyle(Lacquer.silver)
                .frame(width: 72, alignment: .leading)
            Slider(
                value: Binding(
                    get: { model.volume },
                    set: { model.setVolume($0) }
                ),
                in: 0...1
            )
            .tint(Lacquer.pearl)
            .accessibilityLabel("Volume")
            Text(model.volumeLabel)
                .font(.custom("Times New Roman", size: 15))
                .monospacedDigit()
                .foregroundStyle(Lacquer.silver)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var soundPicker: some View {
        HStack(spacing: 8) {
            Text("Sound")
                .font(.custom("Times New Roman", size: 15).weight(.bold))
                .foregroundStyle(Lacquer.silver)
                .frame(width: 72, alignment: .leading)
            ForEach(ReedSound.allCases) { sound in
                let selected = model.sound == sound
                Button {
                    model.setSound(sound)
                } label: {
                    Text(sound.title)
                        .font(.custom("Times New Roman", size: 13).weight(.bold))
                        .foregroundStyle(selected ? Color.black : Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(selected ? Color.white : Color.black.opacity(0.55))
                        )
                        .overlay(Capsule().stroke(Color.white.opacity(selected ? 1 : 0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(sound.title) sound")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var keys: some View {
        VStack(spacing: 8) {
            ForEach(Array(AccordionKey.rows.enumerated()), id: \.element.first?.id) { rowIndex, row in
                let octave = row.first?.octave ?? 0
                SpreadKeyRow(
                    rowIndex: rowIndex,
                    octave: octave,
                    reversed: model.isReversed(octave),
                    keys: row,
                    pressure: model.pressure,
                    noteName: { model.noteName(for: $0) },
                    isHeld: { model.heldKeyCodes.contains($0) },
                    toggle: { model.toggleOrder(octave: octave) }
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ShinyBlackBox())
    }

    private var helpButton: some View {
        Button {
            showGuide.toggle()
        } label: {
            Text("?")
                .font(.custom("Times New Roman", size: 11).weight(.bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(white: 0.98),
                            Color(white: 0.78),
                            Color(white: 0.52),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.black))
                .overlay(Circle().stroke(Color(white: 0.78), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show playing guide")
        .popover(isPresented: $showGuide, arrowEdge: .bottom) {
            GuideView(notice: model.message)
        }
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

private struct GuideView: View {
    var notice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How to play")
                .font(.custom("Snell Roundhand", size: 28))
                .foregroundStyle(Color.white)
            if let notice {
                Text(notice)
                    .font(.custom("Times New Roman", size: 15))
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.45))
            }
            guideLine("Hold a key, then open or close the MacBook lid. The instrument sounds only while the lid is moving, and it gets louder when the lid moves faster. A still lid is silent.")
            guideLine("Q W E R T Y U play octave 3. A S D F G H J play octave 4. Z X C V B N M play octave 5.")
            guideLine("Each octave button flips that row between normal and reverse, so the notes sit on closer keys.")
            guideLine("Air shows how much the bellows are moving. Sustain lengthens the sound after the lid stops and after a key is released. Volume sets the overall loudness.")
            guideLine("Sound chooses the reed: Musette is the wet tremolo, Clarinet is a pure middle reed, Bassoon is dark and low, Violin is bright, and Bandoneon is a dry two-reed beat.")
        }
        .padding(20)
        .frame(width: 380, alignment: .leading)
        .background(Color.black)
    }

    private func guideLine(_ text: String) -> some View {
        Text(text)
            .font(.custom("Times New Roman", size: 15))
            .foregroundStyle(Color.white.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private enum Lacquer {
    static let pearl = Color(white: 0.95)
    static let silver = Color(white: 0.72)
}

private struct TeamCredit: View {
    var moving: Bool
    var pressure: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !moving)) { timeline in
            mark
                .foregroundStyle(platinum)
                .overlay {
                    GeometryReader { geo in
                        let width = geo.size.width
                        let band = width * 0.38
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.35),
                                Color.white,
                                Color.white.opacity(0.35),
                                Color.white.opacity(0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: band)
                        .offset(x: sweep(at: timeline.date) * (width + band) - band)
                        .blendMode(.plusLighter)
                    }
                    .mask(mark)
                    .opacity(moving ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tuned by SENA")
        }
    }

    private var mark: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Tuned by")
                .font(.custom("Times New Roman", size: 13).italic())
            Text("SENA")
                .font(.custom("Times New Roman", size: 16).weight(.bold))
        }
    }

    private var platinum: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.99, blue: 1.0),
                Color(red: 0.84, green: 0.87, blue: 0.92),
                Color(red: 0.96, green: 0.97, blue: 0.99),
                Color(red: 0.62, green: 0.66, blue: 0.72),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func sweep(at date: Date) -> CGFloat {
        let period = 1.35 - min(0.7, pressure) * 0.65
        let cycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        return CGFloat(cycle)
    }
}

private struct ShinyBlackBox: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black)
                .offset(y: 5)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.22),
                            Color(white: 0.08),
                            Color(white: 0.03),
                            Color.black,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.02), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 36)
                .padding(.horizontal, 28)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 7)
                .blur(radius: 0.4)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.7),
                            Color.white.opacity(0.16),
                            Color.black,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.85), lineWidth: 4)
                .padding(3)
                .blur(radius: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.75), radius: 10, y: 6)
        .shadow(color: Color.white.opacity(0.12), radius: 1, y: -1)
    }
}

private enum NoteLayout {
    static let buttonWidth: CGFloat = 58
    static let pitch: CGFloat = buttonWidth + 10
    static let groupWidth: CGFloat = (7 - 0.5) * pitch + buttonWidth

    static func origin(in width: CGFloat) -> CGFloat {
        let centered = (width - groupWidth) / 2
        return min(max(80, centered), max(0, width - groupWidth))
    }
}

private struct SpreadKeyRow: View {
    let rowIndex: Int
    let octave: Int
    let reversed: Bool
    let keys: [AccordionKey]
    let pressure: Double
    let noteName: (AccordionKey) -> String
    let isHeld: (UInt16) -> Bool
    let toggle: () -> Void

    private let rowHeight: CGFloat = 76

    var body: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                let staggered = !rowIndex.isMultiple(of: 2)
                let origin = NoteLayout.origin(in: geometry.size.width)
                let shift = staggered ? NoteLayout.pitch * 0.5 : 0
                ZStack(alignment: .topLeading) {
                    ForEach(Array(keys.enumerated()), id: \.element.id) { index, key in
                        RoundKey(
                            letter: key.letter,
                            note: noteName(key),
                            held: isHeld(key.id),
                            pressure: pressure
                        )
                        .offset(x: origin + shift + CGFloat(index) * NoteLayout.pitch)
                    }
                }
            }
            .frame(height: rowHeight)
            OrderButton(octave: octave, reversed: reversed, action: toggle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OrderButton: View {
    let octave: Int
    let reversed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundFace(pressed: false, marked: reversed) {
                Text(reversed ? "Reverse" : "Normal")
                    .font(.custom("Times New Roman", size: 8).weight(.bold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
            RoundFace(pressed: held) {
                VStack(spacing: 2) {
                    Text(note)
                        .font(.custom("Times New Roman", size: 12).weight(.bold))
                        .foregroundStyle(Color.white)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                        .shadow(color: .white.opacity(held ? 0.9 : 0), radius: 3)
                        .opacity(held ? 0.45 + pressure * 0.55 : 0.28)
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
    var marked: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white, lineWidth: marked ? 4 : 2.5)
                .frame(width: 56, height: 56)
                .offset(y: pressed ? 3 : 0)

            content()
                .frame(width: 48, height: 48)
                .background(face)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(pressed ? 0.35 : 0.7), lineWidth: 1)
                )
                .offset(y: pressed ? 3 : 0)
        }
        .frame(width: 58, height: 62)
        .shadow(color: .black.opacity(pressed ? 0.35 : 0.55), radius: pressed ? 2 : 4, y: pressed ? 1 : 3)
        .animation(.easeOut(duration: 0.07), value: pressed)
    }

    private var face: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: pressed
                        ? [Color(white: 0.08), Color.black]
                        : [Color(white: 0.16), Color(white: 0.05), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            Circle().fill(
                LinearGradient(
                    colors: [Color.white.opacity(pressed ? 0.05 : 0.14), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
        }
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

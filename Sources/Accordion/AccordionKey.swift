import Foundation

struct AccordionKey: Identifiable, Equatable {
    let id: UInt16
    let letter: String
    let octave: Int
    let index: Int

    static let rows: [[AccordionKey]] = [
        scale(letters: [("Q", 12), ("W", 13), ("E", 14), ("R", 15), ("T", 17), ("Y", 16), ("U", 32)], octave: 3),
        scale(letters: [("A", 0), ("S", 1), ("D", 2), ("F", 3), ("G", 5), ("H", 4), ("J", 38)], octave: 4),
        scale(letters: [("Z", 6), ("X", 7), ("C", 8), ("V", 9), ("B", 11), ("N", 45), ("M", 46)], octave: 5),
    ]

    static let byCode: [UInt16: AccordionKey] = Dictionary(
        uniqueKeysWithValues: rows.flatMap { $0 }.map { ($0.id, $0) }
    )

    private static let noteNames = ["C", "D", "E", "F", "G", "A", "B"]
    private static let semitones = [0, 2, 4, 5, 7, 9, 11]

    func note(reversed: Bool) -> String {
        let slot = pitchSlot(reversed: reversed)
        return "\(Self.noteNames[slot])\(octave)"
    }

    func midi(reversed: Bool) -> Int {
        (octave + 1) * 12 + Self.semitones[pitchSlot(reversed: reversed)]
    }

    private func pitchSlot(reversed: Bool) -> Int {
        reversed ? Self.semitones.count - 1 - index : index
    }

    private static func scale(letters: [(String, UInt16)], octave: Int) -> [AccordionKey] {
        letters.enumerated().map { index, letter in
            AccordionKey(id: letter.1, letter: letter.0, octave: octave, index: index)
        }
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A change of a layout's description as the element running its program measured it: which change it was, and
/// where it puts each view it moves, asked where the last frame stood - by the view's key.
struct ProgramChange: Equatable {
    var number: UInt64 = 0
    var places: [Int: HostPlacement] = [:]
}

/// What an element running a layout program keeps to ask it in its own frame: where its motion set out, and what
/// it last asked - by which a change of the description is measured.
/// Design: docs/design/host/layout.md#asked-in-the-hosts-frame
struct ProgramAsking: Equatable {
    /// What the element last asked the program, and what it was answered.
    private struct Asked: Equatable {
        var revision: UInt64
        var samples: [Double]
        var from: [Double]
        var room: LayoutSize
        var targets: [Int: HostPlacement]
    }

    private var last: Asked?

    /// Where the motion set out, the parameters' numbers as they stood then.
    var from: [Double]?

    /// The last change of the description that moved a view.
    private(set) var change = ProgramChange()

    /// Asks `program` its places at `samples` in `room`, the motion having set out from `from`. Another
    /// description, or another place the motion set out from, is measured first: asked where the last frame
    /// stood, each view it puts elsewhere than it was put is a change's - so the arithmetic is asked last where
    /// the parameters stand. Nil for a program that answers at no parameters.
    @MainActor
    mutating func ask(
        _ program: HostLayoutProgram, at samples: [Double], from: [Double], in room: LayoutSize
    ) -> HostLayoutAnswer? {
        guard let place = program.place else { return nil }

        if let last, last.revision != program.revision || last.from != from {
            let before = place(last.samples, from, last.room.width, last.room.height)
            var places: [Int: HostPlacement] = [:]
            for view in before.views where last.targets[view.key] != view.target { places[view.key] = view.target }
            if !places.isEmpty { change = ProgramChange(number: change.number &+ 1, places: places) }
        }
        let answer = place(samples, from, room.width, room.height)
        last = Asked(
            revision: program.revision, samples: samples, from: from, room: room,
            targets: Dictionary(answer.views.map { ($0.key, $0.target) }, uniquingKeysWith: { first, _ in first }))
        return answer
    }
}

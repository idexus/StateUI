// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension MountedElement {
    /// The numbers the layout's parameters stand at this frame: where their channel shows them, else - a state
    /// that moves under no law has none to walk - where they are written. Nil for a layout no numbers move.
    var programSamples: [Double]? {
        guard let state = driven[.parameters]?.state else { return nil }
        return tree?.stateChannels.standing(state)?.value ?? resolvedValue(.parameters)?.numbers
    }

    /// Where the layout's motion set out, its parameters standing at `samples`: there, where nothing moves them -
    /// no hand holds one, and they stand where they are going - and kept while something does, until an axis
    /// passes one of its marks: the motion sets out from the last it passed, either way.
    /// Design: docs/design/views/motion-layout.md#where-a-motion-set-out
    func programSetOut(at samples: [Double], axes: [HostLayoutAxis]) -> [Double] {
        var from = programAsking.from.flatMap { $0.count == samples.count ? $0 : nil } ?? samples
        if programRests(at: samples) {
            from = samples
        } else {
            for axis in axes where samples.indices.contains(axis.lane) {
                if let passed = axis.passed(from: from[axis.lane], to: samples[axis.lane]) { from[axis.lane] = passed }
            }
        }
        programAsking.from = from
        return from
    }

    /// The layout came to rest since it was last asked: where its parameters stand; nil where it did not, or it
    /// moves no numbers. At rest, no hand holds a number of its parameters or a view of its own, the parameters
    /// stand where they are going, and every child stands at its place.
    /// Design: docs/design/host/layout.md#at-rest
    func cameToRest() -> [Double]? {
        guard layoutProgram?.place != nil, let samples = programSamples else { return nil }

        let rests = programRests(at: samples) && !programBodiesMove && !children.contains(where: \.holdsPlacedView)
        guard rests != programRested else { return nil }

        programRested = rests
        return rests ? samples : nil
    }

    /// Whether nothing moves the layout's parameters: no hand holds one of their numbers, and they stand where
    /// they are going.
    private func programRests(at samples: [Double]) -> Bool {
        guard let state = driven[.parameters]?.state, let channels = tree?.stateChannels else { return true }
        guard channels.held(state).isEmpty else { return false }
        return channels.standing(state).map { $0.value == $0.destination } ?? true
    }

    /// What the program answers this frame, asked where the parameters stand. Nil where the program answers at no
    /// parameters, they have no channel yet, or no room was laid out.
    /// Design: docs/design/host/layout.md#asked-in-the-hosts-frame
    func askProgram(_ program: HostLayoutProgram) -> HostLayoutAnswer? {
        guard program.place != nil, let samples = programSamples, let room = laidOutRoom,
              room.width > 0, room.height > 0
        else { return nil }

        let from = programSetOut(at: samples, axes: program.axes)
        return programAsking.ask(
            program, at: samples, from: from, in: LayoutSize(width: room.width, height: room.height))
    }
}

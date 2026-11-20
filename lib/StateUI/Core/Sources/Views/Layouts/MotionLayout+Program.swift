// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension MotionLayout.Run {
    /// The program the host is handed for this description: it keeps the room the host says, and answers the
    /// layout's own size - where it says one - at the parameters as they stand, as its places are worked out.
    /// Design: docs/design/core/layout-program.md#the-program
    func program() -> HostLayoutProgram {
        var measure: (@MainActor (Double?, Double?) -> LayoutSize)?
        if let sized {
            measure = { width, height in sized(width, height, live()) }
        }
        let front: @MainActor (Int, Double, Bool, Bool) -> Double? = { lane, value, _, atRest in
            frontItemUnit(of: lane, at: value, atRest: atRest)
        }
        return states.slot.program(
            revision: UInt64(description), measure: measure, frontItemUnit: front
        ) { width, height in
            let room = Rect(x: 0, y: 0, width: width, height: height)
            if states.room.wrappedValue != room { states.room.wrappedValue = room }
        }
    }
}

extension MotionLayout.Run {
    /// How far the view drawn in front goes for one unit of the axis at `lane` standing at `value`, as the host's
    /// hand asks it: as the run stands, its motion set out where it did - or, `atRest`, as it would rest there.
    /// Design: docs/design/views/interaction.md#the-unit
    func frontItemUnit(of lane: Int, at value: Double, atRest: Bool) -> Double? {
        guard let hand = hands.first(where: { $0.index == lane }) else { return nil }

        let run = on(hand)
        let from = atRest ? run.placing(value, in: parameters.journey.walked) : states.from.wrappedValue ?? live()
        return run.measured(at: value, from: from)
    }
}

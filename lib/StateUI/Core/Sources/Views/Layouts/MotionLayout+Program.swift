// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension MotionLayout.Run {
    /// The program the host is handed for this build of the layout: it keeps the room the host says, and answers
    /// the layout's own size - where it says one - at the parameters as they stand, as its places are worked out.
    /// Design: docs/design/core/layout-program.md#the-program
    func program() -> HostLayoutProgram {
        var measure: (@MainActor (Double?, Double?) -> LayoutSize)?
        if let sized {
            measure = { width, height in sized(width, height, live()) }
        }
        let front: @MainActor (Int, Double, Bool, [Double]?) -> Double? = { lane, value, _, from in
            frontItemUnit(of: lane, at: value, from: from.map(standing(at:)))
        }
        // Asked at no parameters of the host's own: where the layout stands, its motion setting out there.
        let answered: @MainActor () -> HostLayoutAnswer = {
            placed(at: live(), from: live(), in: states.room.wrappedValue)
        }
        let place: @MainActor ([Double], [Double], Double, Double) -> HostLayoutAnswer = { lanes, from, width, height in
            placed(at: standing(at: lanes), from: standing(at: from), in: Rect(x: 0, y: 0, width: width, height: height))
        }
        let axes = hands.map { hand in
            HostLayoutAxis(
                lane: hand.index, segments: hand.segments,
                turn: hand.span.flatMap { span in span.period.map { (span.low, $0) } })
        }
        return states.slot.program(
            measure: measure, frontItemUnit: front, answered: answered,
            run: { standing() }, place: place, axes: axes
        ) { width, height in
            let room = Rect(x: 0, y: 0, width: width, height: height)
            if states.room.wrappedValue != room { states.room.wrappedValue = room }
        }
    }
}

extension MotionLayout.Run {
    /// The parameters with their axes at `lanes`, in the axes' order - a lane short or no number left as the
    /// parameters stand.
    func standing(at lanes: [Double]) -> Parameters {
        var parameters = live()
        for (index, axis) in Parameters.axes.enumerated() where index < lanes.count && lanes[index].isFinite {
            parameters[keyPath: axis] = lanes[index]
        }
        return parameters
    }

    /// Where the layout puts its views as its parameters stand, its motion setting out there: none before a room.
    func standing() -> PlacedRun {
        let room = states.room.wrappedValue
        guard room.width > 0, room.height > 0 else { return PlacedRun() }
        return PlacedRun(pose(in: room, at: live(), from: live()))
    }

    /// What the host is answered at `parameters` in `room`, the motion having set out from `from`: every view's
    /// place and its body, by its identity - the arithmetic asked, and nothing of the run written.
    /// Design: docs/design/core/layout-program.md#the-places-at-any-parameters
    func placed(at parameters: Parameters, from: Parameters, in room: Rect) -> HostLayoutAnswer {
        // One working-out, whatever the room: its views are measured anew, each once - a size measured before
        // the views could be is kept by no room of nothing.
        states.slot.measuring.begin()
        guard room.width > 0, room.height > 0 else { return HostLayoutAnswer() }

        let poses = pose(in: room, at: parameters, from: from)
        let views = slots.enumerated().map { index, slot in
            HostLayoutView(key: slot.identity, target: HostBoundary.placement(of: poses[index]), body: body(index))
        }
        return HostLayoutAnswer(views: views)
    }
}

extension MotionLayout.Run {
    /// How far the view drawn in front goes for one unit of the axis at `lane` standing at `value`, as the host's
    /// hand asks it: its motion having set out from `from` - or, nil, as it would rest there.
    /// Design: docs/design/views/interaction.md#the-unit
    func frontItemUnit(of lane: Int, at value: Double, from: Parameters?) -> Double? {
        guard let hand = hands.first(where: { $0.index == lane }) else { return nil }

        let run = on(hand)
        return run.measured(at: value, from: from ?? run.placing(value, in: parameters.journey.walked))
    }
}

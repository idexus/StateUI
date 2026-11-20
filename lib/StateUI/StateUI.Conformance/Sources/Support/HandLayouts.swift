// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Motion layouts a hand moves, as the cases of a hand over a layout stand them.
enum HandLayouts {
    /// A layout of three views a hand moves across, a hundred points a unit, resting on 0 to 5, its run on `clock` -
    /// `mirrored`, laid out right to left and turned about its middle: the layout's element, once the room is told.
    @MainActor
    static func hand(
        _ s: Session, clock: TestClock, phase: State<Double>, mirrored: Bool = false
    ) throws -> MountedElement {
        // The parameters travel under their state's own motion.
        try? phase.projectedValue.journey.setMotion(.eased(.milliseconds(300), curve: .linear))
        s.start(clock: clock) {
            VStack {
                MotionLayout([0, 1, 2], parameters: phase.projectedValue) { _ in
                    Rectangle()
                        .fill(.red)
                } placements: { _, at in
                    (0..<3).map { Placement(Rect((Double($0) - at) * 50 + 40, 0, 20, 20)) }
                }
                .interaction(
                    .value(phase.projectedValue, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...5).snaps(.every(1))
                        .release(.projected(.eased(.milliseconds(400)))))
                .mirrorsRightToLeft(mirrored)
                .width(100).height(40)
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
            .layoutDirection(mirrored ? .rightToLeft : .inherited)
        }
        s.frames(of: clock, until: 64)
        return try s.element(ofType: .motionLayout)
    }

    /// A square of a board: across and down.
    struct Square: LayoutParameters {
        var x = 0.0
        var y = 0.0

        static var axes: [WritableKeyPath<Square, Double>] { [\.x, \.y] }
    }

    /// A board of three by three squares a hand pans a hundred points a unit either way, its run on `clock`: the layout's
    /// element, once the room is told.
    @MainActor
    static func pan(_ s: Session, clock: TestClock, square: State<Square>) throws -> MountedElement {
        // The parameters travel under their state's own motion.
        try? square.projectedValue.journey.setMotion(.eased(.milliseconds(300), curve: .linear))
        s.start(clock: clock) {
            VStack {
                MotionLayout([0, 1, 2], parameters: square.projectedValue) { _ in
                    Rectangle()
                        .fill(.red)
                } placements: { _, at in
                    (0..<3).map { Placement(Rect((Double($0) - at.x) * 50 + 40, 60 - at.y * 50, 20, 20)) }
                }
                .interaction(
                    .simultaneous([
                        Interaction.value(square.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...2).snaps(.every(1)),
                        Interaction.value(square.projectedValue, axis: \.y, input: .translation(.vertical, unit: .points(100))).reversed(true).range(0...2).snaps(.every(1)),
                    ])
                        .release(.projected(.eased(.milliseconds(400)))))
                .width(200).height(160)
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        s.frames(of: clock, until: 64)
        return try s.element(ofType: .motionLayout)
    }

    /// A layout of three views two fingers move as `input` says, resting on 0.5, 1 and 2 - room for two fingers on
    /// every screen - its run on `clock`: the layout's element, once the room is told.
    @MainActor
    static func fingers(
        _ s: Session, clock: TestClock, phase: State<Double>, input: InteractionInput
    ) throws -> MountedElement {
        // The parameters travel under their state's own motion.
        try? phase.projectedValue.journey.setMotion(.eased(.milliseconds(200), curve: .linear))
        s.start(clock: clock) {
            VStack {
                MotionLayout([0, 1, 2], parameters: phase.projectedValue) { _ in
                    Rectangle()
                        .fill(.red)
                } placements: { _, at in
                    (0..<3).map { Placement(Rect(Double($0) * 80 + 20, 60, 40 * at, 40)) }
                }
                .interaction(
                    .value(phase.projectedValue, input: input).range(0.5...2).snaps([1])
                        .release(.projected(.eased(.milliseconds(400)))))
                .width(300).height(240)
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        s.frames(of: clock, until: 64)
        return try s.element(ofType: .motionLayout)
    }
}

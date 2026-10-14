// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a layout engine's body hands its engine and its handlers: the arithmetic run on the host's frames, and the
// hand - a scroll and a pointer drag - that moves the phase and brings it to rest on a snap target.
// Design: docs/design/views/layout-engine.md#the-hand

extension LayoutEngine {
    /// One view being placed: its identity, its index and its item.
    struct Slot {
        let identity: String
        let index: Int
        let item: Items.Element
    }

    /// The layout as its engine and handlers see it: locals rather than `self`, which holds a class.
    /// Design: docs/design/views/composition.md#handlers-capture-locals
    @MainActor
    struct Run {
        let items: [Items.Element]
        let slots: [Slot]
        let make: (Items.Element) -> Node
        let arithmetic: @MainActor (Rect, Double) -> [Placement]
        let mask: Node?
        let tapped: (gate: any Gate, handler: ValueEventHandler<Items.Element>)?
        let pinned: Binding<Double>?
        let states: States
        let targets: [Double]
        let law: Motion

        /// Whether a scroll lies over the views, and which way it runs.
        let scrolls: Bool
        let across: Bool

        /// How far the hand travels for one unit of the phase.
        let per: Double

        /// Whether a pointer drag moves the run.
        let drags: Bool

        // MARK: - The phase

        /// The lowest and the highest phase the hand reaches.
        var low: Double { targets.first ?? 0 }
        var high: Double { targets.last ?? 0 }

        /// How far the scroll runs beyond its room.
        var reach: Double { (high - low) * per }

        /// The phase as the program last asked for it.
        var phaseAsked: () -> Double {
            let pinned = pinned
            let own = states.ownPhase
            return { pinned?.wrappedValue ?? own.wrappedValue }
        }

        /// The phase as it stands this frame: where the scroller is, or where the program asked - also before the
        /// scroller's first layout, whose offset until then is nobody's.
        func live() -> Double {
            guard scrolls else { return phaseAsked() }
            guard states.measured.wrappedValue > 0 else { return held(states.standing.wrappedValue ?? phaseAsked()) }

            let turned = low + along(states.scrolled.projectedValue.journey.value) / per

            guard turned.isFinite else { return low }

            return held(turned)
        }

        /// A phase held between the lowest and the highest the hand reaches.
        func held(_ phase: Double) -> Double {
            scrolls ? min(max(phase, low), high) : phase
        }

        /// The snap target nearest `phase`.
        func nearest(_ phase: Double) -> Double {
            targets.min { abs($0 - phase) < abs($1 - phase) } ?? phase
        }

        /// The scroller's offset along its axis, and an offset standing the run at `phase`.
        func along(_ offset: Point) -> Double { across ? offset.x : offset.y }

        func offset(at phase: Double) -> Point {
            let distance = (held(phase) - low) * per
            return across ? Point(distance, 0) : Point(0, distance)
        }

        /// A snap target the run passes or rests on, written where it changed.
        func name(_ target: Double) {
            guard target != states.reported.wrappedValue else { return }

            states.reported.wrappedValue = target

            if let pinned {
                if pinned.wrappedValue != target { pinned.wrappedValue = target }
            } else if states.ownPhase.wrappedValue != target {
                states.ownPhase.wrappedValue = target
            }
        }

        /// The program asked for `phase`: the run travels there. A name coming back moves nothing.
        func moved(_ phase: Double) {
            guard phase != states.reported.wrappedValue else { return }

            states.reported.wrappedValue = phase
            states.standing.wrappedValue = held(phase)

            if scrolls {
                states.scrolled.wrappedValue = offset(at: phase)
            } else {
                states.asked.wrappedValue = phase
            }
        }

        // MARK: - On the host's frames

        /// Places every child: the views where the arithmetic says, the scroller over them, the watcher nowhere.
        /// Design: docs/design/views/layout-engine.md#the-run
        func place() {
            let room = states.room.wrappedValue
            let own = Rect(0, 0, room.width, room.height)

            // A room not yet measured places nothing: every child stands in the whole of it until it is.
            if room.width > 0, room.height > 0 {
                let views = fitted(arithmetic(own, live()))

                states.placements.wrappedValue = PlacedRun(
                    views + (scrolls ? [Placement(own, zIndex: Int.max)] : []) + [Placement(.zero, zIndex: Int.min)])

                if scrolls, tapped != nil {
                    states.boxes.wrappedValue = PlacedRun(boxes(in: own, for: views))
                }
            } else {
                states.placements.wrappedValue = PlacedRun()
            }

            guard scrolls else { return }

            let journey = states.scrolled.projectedValue.journey

            // The phase is named as the hand passes a target: one render a target, none a frame - and none on a way
            // the program sent the run, nor while a change of room is regained.
            if states.regaining.wrappedValue {
                regain()
            } else if journey.value == journey.destination {
                name(nearest(live()))
            }
        }

        /// One placement a view: a run that answered fewer or more is said once and made to fit.
        func fitted(_ answered: [Placement]) -> [Placement] {
            guard answered.count != items.count else { return answered }

            complain("A LayoutEngine's placements answered \(answered.count) placements for \(items.count) views. "
                + "One placement a view, in the items' order: the rest stand at the top left, the extra go.")

            let missing = max(items.count - answered.count, 0)
            return Array(answered.prefix(items.count)) + Array(repeating: Placement(.zero), count: missing)
        }

        /// The scroller's content: its length first, then a box under each view as it is drawn, where a tap
        /// lands on it - in the content, which slides under the room.
        func boxes(in room: Rect, for views: [Placement]) -> [Placement] {
            let moved = along(states.scrolled.projectedValue.journey.value)
            let length = Placement(Rect(0, 0, room.width + (across ? reach : 0), room.height + (across ? 0 : reach)),
                                   zIndex: Int.min)

            return [length] + views.map { view in
                let drawn = view.drawnBounds
                return Placement(
                    Rect(drawn.x + (across ? moved : 0), drawn.y + (across ? 0 : moved), drawn.width, drawn.height),
                    zIndex: view.zIndex)
            }
        }

        // MARK: - The hand

        /// The scroller came to rest: the run travels on to the nearest snap target.
        func settle() {
            guard !states.regaining.wrappedValue else { return }

            let target = nearest(live())
            let rest = offset(at: target)

            if abs(along(states.scrolled.projectedValue.journey.value) - along(rest)) > Self.settled {
                states.scrolled.wrappedValue = rest
            }
            states.standing.wrappedValue = target
        }

        /// A pointer drag: the offset follows the pointer, and the run settles where it lets go.
        func drag(_ pan: PanUpdate) {
            let journey = states.scrolled.projectedValue.journey

            switch pan.phase {
            case .began:
                states.dragged.wrappedValue = along(journey.value)

            case .changed:
                let at = states.dragged.wrappedValue - (across ? pan.totalX : pan.totalY)
                journey.snap(to: across ? Point(at, 0) : Point(0, at))

            case .ended, .cancelled:
                let target = nearest(live())

                // Snap the scroller to where the run is, then send it on.
                journey.snap(to: journey.value)
                states.scrolled.wrappedValue = offset(at: target)
                states.standing.wrappedValue = target
            }
        }

        /// After each layout of the scroller the run is put where the phase says; a change of room keeps where it
        /// stood, and a scroller too short for it yet is sent there once it is long enough.
        /// Design: docs/design/views/layout-engine.md#a-change-of-room
        func framed(_ frame: Rect) {
            let room = across ? frame.width : frame.height
            let target = states.standing.wrappedValue ?? held(phaseAsked())
            let sendTo = along(offset(at: target))
            let astray = abs(along(states.scrolled.projectedValue.journey.value) - sendTo) > 1
            let changed = states.measured.wrappedValue > 0 && room != states.measured.wrappedValue

            guard astray || room != states.measured.wrappedValue else { return }

            states.measured.wrappedValue = room
            name(target)
            if astray { states.scrolled.projectedValue.journey.snap(to: offset(at: target)) }
            if changed, laidLength - room < sendTo - 1 { states.regaining.wrappedValue = true }
        }

        /// The run sent back to where it stood once the scroller holds it.
        func regain() {
            let target = states.standing.wrappedValue ?? held(phaseAsked())

            guard laidLength - states.measured.wrappedValue >= along(offset(at: target)) - 1 else { return }

            states.regaining.wrappedValue = false
            states.scrolled.projectedValue.journey.snap(to: offset(at: target))
        }

        /// How long the scroller's run is laid out along its axis.
        var laidLength: Double {
            let laid = states.length.wrappedValue
            return across ? laid.width : laid.height
        }

        /// How near a target the run has to stand to count as resting on it, in device units.
        static var settled: Double { 0.5 }
    }
}

extension Placement {
    /// Where the view is drawn: its bounds taken through its scale about the middle, and moved.
    var drawnBounds: Rect {
        let wide = bounds.width * transform.width
        let tall = bounds.height * transform.height

        return Rect(
            bounds.x + (bounds.width - wide) / 2 + transform.x,
            bounds.y + (bounds.height - tall) / 2 + transform.y,
            wide,
            tall)
    }
}



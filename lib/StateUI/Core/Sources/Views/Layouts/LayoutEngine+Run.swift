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
        let arithmetic: @MainActor (Rect, Phase) -> [Placement]
        let mask: Node?
        let tapped: ValueHandler<Items.Element>?
        let named: ((Phase) -> Void)?

        /// The phase the element wears: the author's, or the layout's own.
        let phase: Binding<Phase>
        let states: States

        /// The axis the hand moves, and where on it the hand may come to rest, lowest first.
        let axis: WritableKeyPath<Phase, Double>?
        let stops: [Double]

        /// The whole phases the run may rest at, and the axes resting on targets of their own.
        let targets: [Phase]
        let axisTargets: [WritableKeyPath<Phase, Double>: [Double]]
        let law: Motion

        /// Whether a scroll lies over the views, and which way it runs.
        let scrolls: Bool
        let across: Bool

        /// How far the hand travels for one unit of the phase.
        let per: Double

        /// Whether a pointer drag moves the run.
        let drags: Bool

        // MARK: - The phase

        /// The lowest and the highest the hand reaches on its axis.
        var low: Double { stops.first ?? 0 }
        var high: Double { stops.last ?? 0 }

        /// How far the scroll runs beyond its room.
        var reach: Double { (high - low) * per }

        /// Whether the hand's axis is on a journey the program or a settle sent it on.
        var travels: Bool {
            let journey = phase.journey
            return onAxis(journey.value) != onAxis(journey.destination)
        }

        /// Where `phase` stands on the hand's axis.
        func onAxis(_ phase: Phase) -> Double {
            axis.map { phase[keyPath: $0] } ?? 0
        }

        /// `phase` with the hand's axis at `value`, the other axes as they are.
        func placing(_ value: Double, in phase: Phase) -> Phase {
            guard let axis else { return phase }

            var placed = phase
            placed[keyPath: axis] = value
            return placed
        }

        /// The phase as it stands this frame: where the host walks it, and under a scroll at rest the hand's axis
        /// where the scroller is - before the scroller's first layout where the run stood, the offset until then
        /// being nobody's.
        /// Design: docs/design/views/layout-engine.md#the-phase
        func live() -> Phase {
            let walked = phase.journey.value

            guard scrolls else { return walked }
            guard states.measured.wrappedValue > 0 else {
                return placing(held(states.standing.wrappedValue ?? onAxis(walked)), in: walked)
            }

            return placing(travels ? held(onAxis(walked)) : scrolledTo(), in: walked)
        }

        /// Where the scroller stands on the hand's axis.
        func scrolledTo() -> Double {
            let turned = low + along(states.scrolled.projectedValue.journey.value) / per

            guard turned.isFinite else { return low }

            return held(turned)
        }

        /// A place on the hand's axis held between the lowest and the highest the hand reaches.
        func held(_ value: Double) -> Double {
            scrolls ? min(max(value, low), high) : value
        }

        /// The place on the hand's axis nearest `value` the hand may rest at.
        func nearest(_ value: Double) -> Double {
            Self.nearest(of: stops, to: value)
        }

        /// Of `values`, the one nearest `value`; the first of two as near.
        static func nearest(of values: [Double], to value: Double) -> Double {
            values.min { abs($0 - value) < abs($1 - value) } ?? value
        }

        /// Where the run comes to rest from `phase` once the hand lets go: an axis with targets of its own on the
        /// nearest of them, and only by its own hand; every other axis at the nearest whole target, by the distance
        /// over them.
        /// Design: docs/design/views/layout-engine.md#coming-to-rest
        func resting(near phase: Phase) -> Phase {
            guard let axis else { return phase }

            var rest = phase
            if let own = axisTargets[axis] {
                rest[keyPath: axis] = Self.nearest(of: own, to: phase[keyPath: axis])
                return rest
            }

            let free = Phase.axes.filter { axisTargets[$0] == nil }
            func apart(_ target: Phase) -> Double {
                free.reduce(0) { sum, each in
                    let gap = target[keyPath: each] - phase[keyPath: each]
                    return sum + gap * gap
                }
            }

            guard let whole = targets.min(by: { apart($0) < apart($1) }) else { return rest }

            for each in free { rest[keyPath: each] = whole[keyPath: each] }
            return rest
        }

        /// The scroller's offset along its axis, and an offset standing the run at `value` on the hand's axis.
        func along(_ offset: Point) -> Double { across ? offset.x : offset.y }

        func offset(at value: Double) -> Point {
            let distance = (held(value) - low) * per
            return across ? Point(distance, 0) : Point(0, distance)
        }

        /// A place on the hand's axis the run passes or rests on, written where the hand holds it: a reading, not a
        /// journey.
        func name(_ target: Double) {
            let journey = phase.journey
            let named = placing(target, in: journey.destination)

            states.reported.wrappedValue = target
            self.named?(named)

            guard let axis, onAxis(journey.value) != target || onAxis(journey.destination) != target else { return }

            journey.snap(axis, to: target)
        }

        /// A destination the run did not name is the program's: where the run is going, which a change of room keeps.
        func heard() {
            let destination = onAxis(phase.journey.destination)
            guard destination != states.reported.wrappedValue else { return }

            states.reported.wrappedValue = destination
            states.standing.wrappedValue = held(destination)
        }

        /// The hand let go where the scroller stands: the run travels on to where it comes to rest.
        func letGo() {
            let journey = phase.journey
            let at = scrolledTo()

            send(to: resting(near: placing(at, in: journey.destination)), from: placing(at, in: journey.value))
        }

        /// The run travels on from `start` to `target` as a journey of the phase, under the layout's motion.
        func send(to target: Phase, from start: Phase) {
            let along = onAxis(target)
            let journey = phase.journey

            states.standing.wrappedValue = along
            guard abs(onAxis(start) - along) * per > Self.settled || target != placing(along, in: journey.destination)
            else { return name(along) }

            states.reported.wrappedValue = along
            named?(target)
            journey.value = start
            _ = journey.move(to: target)
        }

        // MARK: - On the host's frames

        /// Places every child: the views where the arithmetic says, the scroller over them, the watcher nowhere.
        /// Design: docs/design/views/layout-engine.md#the-run
        func place() {
            heard()

            let room = states.room.wrappedValue
            let own = Rect(0, 0, room.width, room.height)

            // A room not yet measured places nothing: every child stands in the whole of it until it is.
            if room.width > 0, room.height > 0 {
                let views = fitted(arithmetic(own, live()))

                states.placements.wrappedValue = PlacedRun(views + (scrolls ? [Placement(own, zIndex: Int.max)] : []))

                if scrolls, tapped != nil {
                    states.boxes.wrappedValue = PlacedRun(boxes(in: own, for: views))
                }
            } else {
                states.placements.wrappedValue = PlacedRun()
            }

            guard scrolls else { return }

            if states.regaining.wrappedValue {
                regain()
            } else {
                follow()
            }
        }

        /// Under a scroll the scroller follows the phase on its way, snapped where the phase stands each frame, and
        /// leads where the phase rests: the phase named as the hand passes halfway between two targets - one render a
        /// target, none a frame. A hand moving the scroller on the phase's way stops the journey there.
        /// Design: docs/design/views/layout-engine.md#the-hand
        func follow() {
            let scroller = states.scrolled.projectedValue.journey
            let mirrored = states.mirrored.wrappedValue

            guard states.measured.wrappedValue > 0 else { return }

            if travels {
                if let mirrored, abs(along(scroller.value) - mirrored) > Self.settled {
                    states.mirrored.wrappedValue = nil
                    name(nearest(scrolledTo()))
                } else {
                    let at = offset(at: onAxis(phase.journey.value))
                    scroller.snap(to: at)
                    states.mirrored.wrappedValue = along(at)
                }
            } else if mirrored != nil {
                // Landed: the scroller stands where the phase arrived.
                states.mirrored.wrappedValue = nil
                scroller.snap(to: offset(at: onAxis(phase.journey.value)))
            } else {
                name(nearest(scrolledTo()))
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
            guard !states.regaining.wrappedValue, !travels else { return }

            letGo()
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
                letGo()
            }
        }

        /// After each layout of the scroller the run is put where the phase says; a change of room keeps where it
        /// stood, and a scroller too short for it yet is sent there once it is long enough.
        /// Design: docs/design/views/layout-engine.md#a-change-of-room
        func framed(_ frame: Rect) {
            let room = across ? frame.width : frame.height
            let target = states.standing.wrappedValue ?? held(onAxis(phase.journey.destination))
            let sendTo = along(offset(at: target))
            let astray = abs(along(states.scrolled.projectedValue.journey.value) - sendTo) > 1
            let changed = states.measured.wrappedValue > 0 && room != states.measured.wrappedValue

            guard astray || room != states.measured.wrappedValue else { return }

            states.measured.wrappedValue = room
            guard !travels else { return }

            name(target)
            if astray { states.scrolled.projectedValue.journey.snap(to: offset(at: target)) }
            if changed, laidLength - room < sendTo - 1 { states.regaining.wrappedValue = true }
        }

        /// The run sent back to where it stood once the scroller holds it.
        func regain() {
            let target = states.standing.wrappedValue ?? held(onAxis(phase.journey.destination))

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

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a layout engine's body hands its engine and its handlers: the arithmetic run on the host's frames, and the
// hand that moves the phase and throws it on to a snap target.
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

        /// The axis the hand moves, where on it the hand may come to rest, lowest first, and how far one turn
        /// takes it where it comes round.
        let axis: WritableKeyPath<Phase, Double>?
        let stops: [Double]
        let period: Double?

        /// The whole phases the run may rest at, and the axes resting on targets of their own.
        let targets: [Phase]
        let axisTargets: [WritableKeyPath<Phase, Double>: [Double]]
        let law: Motion

        /// Whether a hand moves the run, which way, how far it travels for one unit of the phase, and how a throw
        /// goes on.
        let moves: Bool
        let across: Bool
        let per: Double
        let throwing: Motion

        // MARK: - The phase

        /// The lowest and the highest target on the hand's axis.
        var low: Double { stops.first ?? 0 }
        var high: Double { stops.last ?? 0 }

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

        /// The phase as it stands this frame: where the host walks it, the hand's axis where the hand holds it.
        /// Design: docs/design/views/layout-engine.md#the-phase
        func live() -> Phase {
            let walked = phase.journey.value

            guard let held = states.held.wrappedValue else { return walked }

            return placing(held, in: walked)
        }

        /// The place on the hand's axis nearest `value` the hand may rest at - a turn on or back where it comes
        /// round.
        func nearest(_ value: Double) -> Double {
            Self.nearest(of: around(stops, near: value), to: value)
        }

        /// `values` of the hand's axis as they come round near `value`: the turn it stands in and one either side.
        func around(_ values: [Double], near value: Double) -> [Double] {
            guard let period else { return values }

            let turn = ((value - low) / period).rounded(.down)
            return [turn - 1, turn, turn + 1].flatMap { turn in values.map { $0 + turn * period } }
        }

        /// Of `values`, the one nearest `value`; the first of two as near.
        static func nearest(of values: [Double], to value: Double) -> Double {
            values.min { abs($0 - value) < abs($1 - value) } ?? value
        }

        /// Where the run comes to rest from `phase` once the hand lets go: an axis with targets of its own on the
        /// nearest of them, and only by its own hand; every other axis at the nearest whole target, by the distance
        /// over them - the hand's axis taken the turn nearest where it comes round.
        /// Design: docs/design/views/layout-engine.md#coming-to-rest
        func resting(near phase: Phase) -> Phase {
            guard let axis else { return phase }

            var rest = phase
            if let own = axisTargets[axis] {
                rest[keyPath: axis] = Self.nearest(of: around(own, near: phase[keyPath: axis]), to: phase[keyPath: axis])
                return rest
            }

            let free = Phase.axes.filter { axisTargets[$0] == nil }
            let turned = targets.map { target in placing(turnNearest(onAxis(target), to: onAxis(phase)), in: target) }
            func apart(_ target: Phase) -> Double {
                free.reduce(0) { sum, each in
                    let gap = target[keyPath: each] - phase[keyPath: each]
                    return sum + gap * gap
                }
            }

            guard let whole = turned.min(by: { apart($0) < apart($1) }) else { return rest }

            for each in free { rest[keyPath: each] = whole[keyPath: each] }
            return rest
        }

        /// `value` a whole number of turns on or back, nearest `other`, where the hand's axis comes round.
        func turnNearest(_ value: Double, to other: Double) -> Double {
            guard let period else { return value }

            return value + ((other - value) / period).rounded() * period
        }

        /// A place on the hand's axis the run passes or rests on, written where the hand holds it: a reading, not a
        /// journey, and the axis alone.
        func name(_ target: Double) {
            let journey = phase.journey

            named?(placing(target, in: journey.destination))

            guard let axis, onAxis(journey.value) != target || onAxis(journey.destination) != target else { return }

            journey.snap(axis, to: target)
        }

        /// The run travels on from `start` to `target` as a journey of the phase, under the layout's motion, the
        /// hand's axis setting out at `speed` units a second.
        func send(to target: Phase, from start: Phase, speed: Double) {
            let along = onAxis(target)
            let journey = phase.journey

            guard abs(onAxis(start) - along) * per > Self.settled || target != placing(along, in: journey.destination)
            else { return name(along) }

            named?(target)
            journey.value = start
            if speed != 0 { journey.velocity = placing(speed, in: journey.velocity) }
            _ = journey.move(to: target)
        }

        // MARK: - On the host's frames

        /// Places every view where the arithmetic says, a throw under way carried on to `now` first; again next
        /// frame while it goes on.
        /// Design: docs/design/views/layout-engine.md#the-run
        func place(at now: Double) -> EngineAnswer {
            let flying = fly(at: now)
            let room = states.room.wrappedValue

            // A room not yet measured places nothing: every view stands in the whole of it until it is.
            if room.width > 0, room.height > 0 {
                states.placements.wrappedValue = PlacedRun(
                    fitted(arithmetic(Rect(0, 0, room.width, room.height), live())))
            } else {
                states.placements.wrappedValue = PlacedRun()
            }

            return flying ? .again : .wait
        }

        /// The throw under way carried on to `now`: the hand's axis held where the input's `throwing` has brought
        /// it - setting out at the hand's speed and slowing to a stop on the target - and let go once there.
        /// A destination written meanwhile is the program's, and ends the throw. Whether it goes on.
        /// Design: docs/design/views/layout-engine.md#a-throw
        func fly(at now: Double) -> Bool {
            guard var fling = states.flung.wrappedValue else { return false }

            guard onAxis(phase.journey.destination) == fling.to else {
                states.flung.wrappedValue = nil
                states.held.wrappedValue = nil
                return false
            }

            let began = fling.began ?? now
            if fling.began == nil {
                fling.began = now
                states.flung.wrappedValue = fling
            }

            guard let at = Self.flown(fling, after: now - began, by: throwing) else {
                states.flung.wrappedValue = nil
                states.held.wrappedValue = nil
                return false
            }

            states.held.wrappedValue = at
            return true
        }

        /// One view inside the holder the run places, so the author's own properties on the view are never
        /// overwritten by a frame of arithmetic; a shade is the holder's second child. Where its view is not, a
        /// holder lets input through to the layout.
        func wrapped(_ slot: Slot) -> ModifiedContent {
            let holder = Grid { BuiltViews(nodes: [make(slot.item)] + (mask.map { [$0] } ?? [])) }

            guard let tapped else { return ModifiedContent(node: holder.letsInputThrough(true).node) }

            let item = slot.item
            return ModifiedContent(node: holder.onTapped(gate: tapped.gate) { try await tapped.run(item) }.node)
        }

        /// One placement a view: a run that answered fewer or more is said once and made to fit.
        func fitted(_ answered: [Placement]) -> [Placement] {
            guard answered.count != items.count else { return answered }

            complain("A LayoutEngine's placements answered \(answered.count) placements for \(items.count) views. "
                + "One placement a view, in the items' order: the rest stand at the top left, the extra go.")

            let missing = max(items.count - answered.count, 0)
            return Array(answered.prefix(items.count)) + Array(repeating: Placement(.zero), count: missing)
        }

        // MARK: - The hand

        /// The hand over the element: it takes the run where it is shown, moves the hand's axis with it - half as
        /// far past an end of a run that does not come round - and names each target it passes; let go, it throws
        /// the run on to the target nearest where the throw would end.
        /// Design: docs/design/views/layout-engine.md#the-hand
        func hand(_ gesture: GesturePhase, moved: Point, speed: Point) {
            let journey = phase.journey

            switch gesture {
            case .began:
                take(at: onAxis(journey.value))

            case .changed:
                // A move with no beginning heard is one: the run is taken where it is shown.
                let held = states.held.wrappedValue ?? take(at: onAxis(journey.value))
                let step = -(across ? moved.x : moved.y) / per
                let beyond = period == nil && (held + step < low || held + step > high)
                let next = held + (beyond ? step / 2 : step)

                states.held.wrappedValue = next
                name(nearest(next))

            case .ended, .cancelled:
                guard let held = states.held.wrappedValue else { return }

                let thrown = gesture == .ended ? -(across ? speed.x : speed.y) / per : 0
                let reach = held + Self.carried(thrown, by: throwing)
                let end = period == nil ? min(max(reach, low), high) : reach
                let target = resting(near: placing(end, in: journey.destination))

                let along = onAxis(target)

                // Thrown on to a target ahead, the run goes on there as the input throws; let go still, or too
                // slowly to carry it past the target it stands nearest, the run slides there under the layout's
                // motion.
                guard abs(thrown) * per >= Self.throwing, (along - held) * thrown > 0 else {
                    states.held.wrappedValue = nil
                    return send(to: target, from: placing(held, in: journey.value), speed: 0)
                }

                name(along)
                if target != placing(along, in: journey.destination) { _ = journey.move(to: target) }
                states.flung.wrappedValue = LayoutFling(from: held, to: along, speed: thrown)
            }
        }

        /// The run taken by the hand at `value` on its axis: a journey or a throw under way stops there.
        @discardableResult
        func take(at value: Double) -> Double {
            states.flung.wrappedValue = nil
            states.held.wrappedValue = value
            name(nearest(value))
            return value
        }

        /// How much farther a throw at `speed` units a second carries under `throwing`: eased, the hand's speed for
        /// its length over how steeply its curve sets out; a spring, for a third of its response - as far as a
        /// `cubicOut` of that length.
        static func carried(_ speed: Double, by throwing: Motion) -> Double {
            let length = Double(throwing.isInherited ? 400 : throwing.milliseconds) / 1_000

            switch throwing.law {
            case .eased: return speed * length / max(HostMotionLaw.slope(throwing.curve, at: 0), 0.1)
            case .spring: return speed * length / 3
            }
        }

        /// Where `fling` stands `elapsed` milliseconds in, under `throwing`, or nil once it is on its target. Eased,
        /// it follows the curve over a length that sets it out at the hand's speed - long as the motion's own where
        /// the target is where the throw would end, shorter where it is nearer; a spring settles from the hand's
        /// speed.
        static func flown(_ fling: LayoutFling, after elapsed: Double, by throwing: Motion) -> Double? {
            let left = fling.to - fling.from

            guard throwing.law == .eased else {
                let sample = HostMotionLaw.sample(
                    throwing, elapsed: elapsed, from: [fling.from], destination: [fling.to],
                    velocity: [fling.speed / 1_000])
                return sample.rested ? nil : sample.value.first
            }

            let length = Double(throwing.isInherited ? 400 : throwing.milliseconds)
            let setsOut = max(HostMotionLaw.slope(throwing.curve, at: 0), 0.1)
            let flight = min(max(abs(left / fling.speed) * setsOut * 1_000, shortest), max(length * 2, shortest))
            let progress = max(elapsed, 0) / flight

            return progress >= 1 ? nil : fling.from + left * HostMotionLaw.ease(throwing.curve, at: progress)
        }

        /// How fast a hand must let go to throw, in device units a second, and the shortest a throw slows in, in
        /// milliseconds.
        static var throwing: Double { 50 }
        static var shortest: Double { 80 }

        /// How near a target the run has to stand to count as resting on it, in device units.
        static var settled: Double { 0.5 }
    }
}

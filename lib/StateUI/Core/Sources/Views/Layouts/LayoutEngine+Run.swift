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
        let arithmetic: @MainActor (Rect, Phase, Phase) -> [Placement]

        /// Which description of the layout the run is: a render that describes it again makes another.
        let description: Int
        let mask: Node?
        let tapped: ValueHandler<Items.Element>?
        let named: ((Phase) -> Void)?
        let itemStart: ItemDragStart?
        let dragged: (@MainActor (ItemDrag<Items.Element>) throws -> Void)?
        let dismissal: LayoutDismissal<Items.Element>?

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

        /// Whether a hand moves the run, which way, how far it travels for one unit of the phase where the input
        /// says, whether it moves it one target at most, and how a throw goes on.
        let moves: Bool
        let across: Bool
        let travel: LayoutInput.Travel
        let swipes: Bool
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
            guard let held = states.held.wrappedValue else { return phase.journey.value }

            return placing(held, in: phase.journey.walked)
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

            guard abs(onAxis(start) - along) * (unit(at: along) ?? 1) > Self.settled
                || target != placing(along, in: journey.destination)
            else { return name(along) }

            named?(target)
            journey.value = start
            if speed != 0 { journey.velocity = placing(speed, in: journey.velocity) }
            _ = journey.move(to: target)
        }

        // MARK: - On the host's frames

        /// Places every view where the arithmetic says - a throw under way carried on to `now` first, a change of
        /// the description on its way from where each view was shown - again next frame while either goes on.
        /// Design: docs/design/views/layout-engine.md#the-run
        func place(at now: Double, reducesMotion: Bool) -> EngineAnswer {
            let flying = fly(at: now, reducesMotion: reducesMotion)
            let room = states.room.wrappedValue

            // Where the hand, a throw or an approach holds the run is the phase's value, for whatever follows it.
            phase.journey.show(
                states.held.wrappedValue.map { placing($0, in: phase.journey.walked) },
                by: ObjectIdentifier(states.held.storage))

            // A room not yet measured places nothing: every view stands in the whole of it until it is.
            guard room.width > 0, room.height > 0 else {
                states.placements.wrappedValue = PlacedRun()
                return flying ? .again : .wait
            }

            // A change of the description or of where the motion set out is measured before the run is worked
            // out where it stands now.
            let phase = live()
            let from = setOut(at: phase)
            let memory = changed(at: now, from: from, reducesMotion: reducesMotion)
            let poses = fitted(arithmetic(Rect(0, 0, room.width, room.height), phase, from))
            let changing = show(
                poses, after: memory, at: now, phase: phase, from: from, room: room, reducesMotion: reducesMotion)
            return flying || changing ? .again : .wait
        }

        /// Where the run's motion set out, the run standing at `phase`: there, where nothing moves it - no hand, no
        /// throw, the phase where it is going - and kept while something does, until it passes a target on the
        /// hand's axis: the motion sets out from the last it passed, either way.
        /// Design: docs/design/views/layout-engine.md#where-a-motion-set-out
        func setOut(at phase: Phase) -> Phase {
            let journey = self.phase.journey
            let resting = states.held.wrappedValue == nil && states.flung.wrappedValue == nil
                && journey.value == journey.destination
            var from = states.from.wrappedValue ?? phase
            if resting {
                from = phase
            } else if let passed = passed(from: onAxis(from), to: onAxis(phase)) {
                from = placing(passed, in: from)
            }

            if states.from.wrappedValue != from { states.from.wrappedValue = from }
            return from
        }

        /// Of the targets on the hand's axis beyond `start` up to `value`, the one nearest `value`: the last the run
        /// passed going from one to the other; nil where it passed none.
        func passed(from start: Double, to value: Double) -> Double? {
            let beyond = around(stops, near: value).filter { value > start ? $0 > start && $0 <= value : $0 < start && $0 >= value }
            return value > start ? beyond.max() : beyond.min()
        }

        /// The throw or the approach under way carried on to `now`: the hand's axis held where its motion has
        /// brought it, and let go once on the target - at once for an approach under less motion. A destination
        /// written meanwhile is the program's, and ends it. Whether it goes on.
        /// Design: docs/design/views/layout-engine.md#a-throw
        func fly(at now: Double, reducesMotion: Bool) -> Bool {
            guard var fling = states.flung.wrappedValue else { return false }

            guard onAxis(phase.journey.destination) == fling.to, fling.thrown || !reducesMotion else {
                states.flung.wrappedValue = nil
                states.held.wrappedValue = nil
                return false
            }

            let began = fling.began ?? now
            if fling.began == nil {
                fling.began = now
                states.flung.wrappedValue = fling
            }

            guard let at = Self.flown(fling, after: now - began) else {
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
                take(at: onAxis(live()))

            case .changed:
                // A move with no beginning heard is one: the run is taken where it is shown.
                let held = states.held.wrappedValue ?? take(at: onAxis(journey.value))
                // A room not yet measured draws no view, so a hand over it moves none.
                guard let per = unit(at: held) else { return }

                let step = -(across ? moved.x : moved.y) / per
                let free = period == nil ? runPoint(of: handPoint(of: held) + step) : held + step
                let next = reach.map { min(max(free, $0.lowerBound), $0.upperBound) } ?? free

                states.held.wrappedValue = next
                name(nearest(next))

            case .ended, .cancelled:
                guard let held = states.held.wrappedValue else { return }

                let measured = unit(at: held)
                let per = measured ?? 1
                let thrown = gesture == .ended && measured != nil ? -(across ? speed.x : speed.y) / per : 0
                let carried = held + Self.carried(thrown, by: throwing)
                let end = period == nil ? min(max(carried, low), high) : carried
                let target = swiped(from: held, thrown: abs(thrown) * per >= Self.throwing ? thrown : 0)
                    .map { placing($0, in: journey.destination) } ?? resting(near: placing(end, in: journey.destination))
                states.grip.wrappedValue = nil

                let along = onAxis(target)
                let left = along - held
                let motion = law.resolved(against: .standard)

                // Thrown on to a target ahead, the run goes on there as the input throws - onto the next target no
                // slower than the layout's motion moves a unit; let go still, thrown back or slower than that, it
                // approaches the target under that motion over as much of its length as the way left is of a unit.
                // Design: docs/design/views/layout-engine.md#coming-onto-a-target
                let flight = Self.flight(left, at: thrown, by: throwing)
                let isThrow = abs(thrown) * per >= Self.throwing && left * thrown > 0
                    && (!next(from: held, to: along) || flight <= abs(left) * Double(motion.milliseconds))

                name(along)
                if target != placing(along, in: journey.destination) { _ = journey.move(to: target) }
                guard abs(left) * per > Self.settled, !motion.isCustom || isThrow else {
                    states.held.wrappedValue = nil
                    return
                }

                states.flung.wrappedValue = isThrow
                    ? LayoutFling(from: held, to: along, speed: thrown, motion: throwing, flight: flight, thrown: true)
                    : LayoutFling(
                        from: held, to: along, speed: thrown, motion: Self.approach(motion, over: left),
                        flight: abs(left) * Double(motion.milliseconds), thrown: false)
            }
        }

        /// Whether `to` is the next target from `from` on the hand's axis: none stands between them.
        func next(from: Double, to: Double) -> Bool {
            !around(stops, near: from).contains { min(from, to) < $0 && $0 < max(from, to) }
        }

        /// Where the hand stands, in units of the axis, for the run standing at `value`: past an end of a run
        /// that does not come round, as far beyond it as the hand went for the run to give that much.
        func handPoint(of value: Double) -> Double {
            value > high ? high + Self.pulled(value - high) : value < low ? low - Self.pulled(low - value) : value
        }

        /// Where the run stands for the hand at `point`: past an end of a run that does not come round, less and
        /// less of the way beyond it - `handPoint(of:)`'s inverse.
        /// Design: docs/design/views/layout-engine.md#the-hand
        func runPoint(of point: Double) -> Double {
            point > high ? high + Self.given(point - high) : point < low ? low - Self.given(low - point) : point
        }

        /// How far past an end the run gives for the hand `beyond` it, in units: half as far at first, then less
        /// and less, never `overreach`.
        static func given(_ beyond: Double) -> Double {
            overreach * (1 - 1 / (beyond / 2 / overreach + 1))
        }

        /// How far past an end the hand went for the run to give `given`: `given(_:)`'s inverse.
        static func pulled(_ given: Double) -> Double {
            let given = min(given, overreach * 0.999)
            return given / (1 - given / overreach) * 2
        }

        /// The most a run gives past an end, in units of the phase.
        static var overreach: Double { 0.75 }

        /// How far the hand travels for one unit of its axis at `value`, in device units: the input's points, the
        /// room's length, or as far as the view drawn in front of those the phase moves - the highest, then the one
        /// nearest the middle - goes for one unit there, so the hand carries it with it. A run with nothing moving
        /// takes a room's length a unit; one whose room is not measured yet, none.
        /// Design: docs/design/views/layout-engine.md#the-hand
        func unit(at value: Double) -> Double? {
            switch travel {
            case .points(let points):
                return points
            case .room:
                let room = states.room.wrappedValue
                guard room.width > 0, room.height > 0 else { return nil }
                return across ? room.width : room.height
            case .front:
                if swipes, let grip = states.grip.wrappedValue { return grip.unit }
                return measured(at: value, from: states.from.wrappedValue ?? live())
            }
        }

        /// How far the view drawn in front of those the phase moves goes for one unit of the hand's axis at `value`,
        /// the motion setting out from `from`; a room's length where nothing moves, none where the room is not
        /// measured yet.
        func measured(at value: Double, from: Phase) -> Double? {
            let laid = states.room.wrappedValue
            guard laid.width > 0, laid.height > 0 else { return nil }

            let room = Rect(0, 0, laid.width, laid.height)
            let length = across ? room.width : room.height
            let shown = live()
            func middle(_ placement: Placement) -> Double {
                across ? placement.bounds.x + placement.bounds.width / 2 : placement.bounds.y + placement.bounds.height / 2
            }

            let here = arithmetic(room, placing(value, in: shown), from)
            let before = arithmetic(room, placing(value - Self.probe, in: shown), from)
            let after = arithmetic(room, placing(value + Self.probe, in: shown), from)
            let moving = here.indices.prefix(min(before.count, after.count)).compactMap { index in
                let moved = abs(middle(after[index]) - middle(before[index])) / (2 * Self.probe)
                return moved >= 1 ? (index: index, moved: moved) : nil
            }
            let front = moving.min { one, other in
                let (first, second) = (here[one.index], here[other.index])
                return first.zIndex != second.zIndex
                    ? first.zIndex > second.zIndex
                    : abs(middle(first) - length / 2) < abs(middle(second) - length / 2)
            }

            return front?.moved ?? max(length, 1)
        }

        /// How far either side of where the run stands the view in front is measured, in units of the phase.
        static var probe: Double { 0.01 }

        /// A wheel's notches over the element: the run goes on from the target it is going to - a throw's or a
        /// journey's - to the target as many on as the notches turned, under the layout's motion. A swipe's go one
        /// target from where the run rests, and wait while it goes. A hand holding the run keeps it.
        /// Design: docs/design/views/layout-engine.md#a-wheels-notch
        func step(_ notches: Point) {
            let count = Int((-(across ? notches.x : notches.y)).rounded())
            guard count != 0, !stops.isEmpty else { return }
            guard states.held.wrappedValue == nil || states.flung.wrappedValue != nil else { return }

            let journey = phase.journey
            if swipes {
                guard states.flung.wrappedValue == nil, journey.value == journey.destination else { return }
            }
            let start = live()
            let along = stepped(onAxis(journey.destination), by: swipes ? count.signum() : count)
            let target = resting(near: placing(along, in: journey.destination))

            states.flung.wrappedValue = nil
            states.held.wrappedValue = nil
            send(to: target, from: start, speed: 0)
        }

        /// The target `count` on from the one nearest `value` - back for fewer than nought - held to the ends of a run
        /// that does not come round, a turn on or back where it does.
        func stepped(_ value: Double, by count: Int) -> Double {
            let turns: [Double] = period.map { period in
                let turn = ((value - low) / period).rounded(.down)
                return [turn - 1, turn, turn + 1]
            } ?? [0]
            var nearest = (turn: 0.0, index: 0, gap: Double.infinity)
            for turn in turns {
                for (index, stop) in stops.enumerated() {
                    let gap = abs(stop + turn * (period ?? 0) - value)
                    if gap < nearest.gap { nearest = (turn, index, gap) }
                }
            }

            let moved = nearest.index + count
            guard let period else { return stops[min(max(moved, 0), stops.count - 1)] }

            let round = (Double(moved) / Double(stops.count)).rounded(.down)
            return stops[moved - Int(round) * stops.count] + (nearest.turn + round) * period
        }

        /// The run taken by the hand at `value` on its axis: a journey or a throw under way stops there. A swiping
        /// hand grips it at the target nearest, with the unit the run would have standing there.
        @discardableResult
        func take(at value: Double) -> Double {
            states.flung.wrappedValue = nil
            states.held.wrappedValue = value
            if swipes {
                let target = nearest(value)
                let resting = placing(target, in: phase.journey.value)
                let unit = travel == .front ? measured(at: target, from: resting) : unit(at: target)
                states.grip.wrappedValue = LayoutGrip(target: target, unit: unit)
            }
            name(nearest(value))
            return value
        }

        /// How far a swiping hand moves the run on its axis: from the target before the one it took it at to the
        /// one after; nil for a scroll.
        /// Design: docs/design/views/layout-engine.md#a-swipe
        var reach: ClosedRange<Double>? {
            guard swipes, let grip = states.grip.wrappedValue else { return nil }

            return stepped(grip.target, by: -1)...stepped(grip.target, by: 1)
        }

        /// Where a swipe let go at `held` comes to rest: thrown, the next of its reach's targets that way - where it
        /// took the run or the one beyond; let go still, the nearest of them. Nil for a scroll.
        /// Design: docs/design/views/layout-engine.md#a-swipe
        func swiped(from held: Double, thrown: Double) -> Double? {
            guard let reach, let grip = states.grip.wrappedValue else { return nil }

            let targets = [reach.lowerBound, grip.target, reach.upperBound]
            guard thrown != 0 else { return Self.nearest(of: targets, to: held) }

            let ahead = targets.filter { thrown > 0 ? $0 > held : $0 < held }
            return (thrown > 0 ? ahead.min() : ahead.max()) ?? Self.nearest(of: targets, to: held)
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
        static func flown(_ fling: LayoutFling, after elapsed: Double) -> Double? {
            let left = fling.to - fling.from

            guard fling.motion.law == .eased else {
                let sample = HostMotionLaw.sample(
                    fling.motion, elapsed: elapsed, from: [fling.from], destination: [fling.to],
                    velocity: [fling.speed / 1_000])
                return sample.rested ? nil : sample.value.first
            }

            let progress = fling.flight > 0 ? max(elapsed, 0) / fling.flight : 1
            return progress >= 1 ? nil : fling.from + left * HostMotionLaw.ease(fling.motion.curve, at: progress)
        }

        /// How long a throw at `speed` units a second takes to go `left` on under `throwing`, in milliseconds: the
        /// length that sets it out at the hand's speed - a spring's as a `cubicOut` of its response would - never
        /// shorter than `shortest`, nor longer than twice the motion's length.
        static func flight(_ left: Double, at speed: Double, by throwing: Motion) -> Double {
            let length = Double(throwing.isInherited ? 400 : throwing.milliseconds)
            let setsOut = throwing.law == .eased ? max(HostMotionLaw.slope(throwing.curve, at: 0), 0.1) : 3
            let setting = speed == 0 ? .infinity : abs(left / speed) * setsOut * 1_000

            return min(max(setting, shortest), max(length * 2, shortest))
        }

        /// The layout's `motion` for an approach `left` units long, a unit a length: eased, as long as the way left
        /// takes; a spring, its response cut alike.
        static func approach(_ motion: Motion, over left: Double) -> Motion {
            let length = Duration.milliseconds(Int((abs(left) * Double(motion.milliseconds)).rounded()))

            switch motion.law {
            case .eased: return .eased(length, motion.curve)
            case .spring: return .spring(response: length, damping: motion.factor)
            }
        }

        /// How fast a hand must let go to throw, in device units a second, and the shortest a throw slows in, in
        /// milliseconds.
        static var throwing: Double { 50 }
        static var shortest: Double { 80 }

        /// How near a target the run has to stand to count as resting on it, in device units.
        static var settled: Double { 0.5 }
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a phase layout's body hands its engine and its handlers: the arithmetic run on the host's frames, and the
// hands that move the phase and throw it on to where it rests.
// Design: docs/design/views/phase-layout.md#the-hand

import StateUIFoundation

extension PhaseLayout {
    /// One axis the hand or the fingers move: its place in the phase's `axes`, by which the hand's hold, its throw
    /// and its grip are kept, the axis, what moves it and how a throw goes on, the ends of its range, where on it the
    /// run may come to rest, lowest first - none for anywhere in the range - how far one turn takes it where it
    /// comes round, and where the arithmetic is asked, lowest first, the ends included - nil for every frame.
    struct Hand {
        let index: Int
        let axis: WritableKeyPath<Phase, Double>
        let gesture: LayoutInput.Gesture
        let throwing: Motion
        let low: Double
        let high: Double
        let stops: [Double]
        let period: Double?
        let knots: [Double]?

        /// Which way the hand moves the axis, where the hand does rather than two fingers.
        var way: LayoutInput.Axis? {
            guard case .hand(let way, _, _) = gesture else { return nil }
            return way
        }
    }

    /// One view being placed: its identity, its index and its item.
    struct Slot {
        let identity: Int
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
        let holder: (Items.Element) -> Node
        let arithmetic: @MainActor (Rect, Phase, Phase) -> [Placement]

        /// The curve between the poses at keyframes, whether the arithmetic reads where the motion set out, the
        /// poses kept for this description, and the states the arithmetic follows, whose writes let them go.
        let curve: any LayoutInterpolation
        let readsFrom: Bool
        let kept: LayoutPoses
        let followed: [any FollowedState]

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

        /// Every axis the hand and the fingers move, and the one the run works on: the first the hand moves unless
        /// `on(_:)` says another.
        let hands: [Hand]
        var focus: Hand?
        let law: Motion

        /// The law the run moves under: its own, or - `.inherited` - the application's, as a host's channel answers
        /// it, so a change and a program's write of the phase travel alike.
        /// Design: docs/design/views/phase-layout.md#a-change-at-the-current-phase
        var resolvedLaw: Motion { law.resolved(against: StandardEnvironment.application.motion) }

        /// The run working on `hand`'s axis.
        func on(_ hand: Hand) -> Run {
            var run = self
            run.focus = hand
            return run
        }

        /// The axis in focus, where on it the run may come to rest, lowest first, how far one turn takes it where it
        /// comes round, and the ends of its range.
        var axis: WritableKeyPath<Phase, Double>? { focus?.axis }
        var stops: [Double] { focus?.stops ?? [] }
        var period: Double? { focus?.period }
        var low: Double { focus?.low ?? 0 }
        var high: Double { focus?.high ?? 0 }

        /// The ways the hand moves the run - every way for a pan, axes moved across and down - and whether it does.
        var ways: Set<LayoutInput.Axis> { Set(hands.compactMap { $0.way }) }
        var moves: Bool { !ways.isEmpty }
        var pans: Bool { ways.count > 1 }

        /// Which way the hand moves the axis in focus, how far it travels for one unit where the input says, whether
        /// it moves it one snap at most, and how a throw goes on.
        var across: Bool { focus?.way != .vertical }
        var travel: LayoutInput.Travel {
            guard case .hand(_, let travel, _) = focus?.gesture else { return .front }
            return travel
        }
        var swipes: Bool {
            guard case .hand(_, _, let swipes) = focus?.gesture else { return false }
            return swipes
        }
        var throwing: Motion { focus?.throwing ?? LayoutInput.scroll(.horizontal).throwing }

        /// Where the hand holds the axis in focus, while it does.
        var held: Double? {
            get { focus.flatMap { states.held.wrappedValue[$0.index] } }
            nonmutating set { if let index = focus?.index { states.held.wrappedValue[index] = newValue } }
        }

        /// Where a swiping hand took the axis in focus, while it holds it.
        var grip: LayoutGrip? {
            get { focus.flatMap { states.grip.wrappedValue[$0.index] } }
            nonmutating set { if let index = focus?.index { states.grip.wrappedValue[index] = newValue } }
        }

        /// Whether the axis in focus is moved by its logarithm: a magnification, multiplied by the fingers.
        var multiplies: Bool { focus?.gesture == .magnification }

        /// `value` of the axis in focus where the hand works on it - its logarithm for a magnification - and back.
        func toHand(_ value: Double) -> Double { multiplies ? log(max(value, .leastNormalMagnitude)) : value }
        func fromHand(_ point: Double) -> Double { multiplies ? exp(point) : point }

        // MARK: - The phase

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

        /// The phase as it stands this frame: where the host walks it, each hand's axis where that hand holds it.
        /// Design: docs/design/views/phase-layout.md#the-phase
        func live() -> Phase {
            holding(phase.journey.walked) ?? phase.journey.value
        }

        /// `phase` with each hand's axis where that hand holds it; nil where no hand holds the run.
        func holding(_ phase: Phase) -> Phase? {
            let held = states.held.wrappedValue
            guard !held.isEmpty else { return nil }

            var holding = phase
            for hand in hands { if let value = held[hand.index] { holding[keyPath: hand.axis] = value } }
            return holding
        }

        /// The place on the hand's axis nearest `value` the hand may rest at - a turn on or back where it comes
        /// round, the nearest by its logarithm on a magnification's.
        func nearest(_ value: Double) -> Double {
            nearest(of: around(stops, near: value), to: value)
        }

        /// Of `values` on the axis in focus, the one nearest `value` where the hand works on them; the first of two
        /// as near.
        func nearest(of values: [Double], to value: Double) -> Double {
            let point = toHand(value)
            return values.min { abs(toHand($0) - point) < abs(toHand($1) - point) } ?? value
        }

        /// `values` of the hand's axis as they come round near `value`: the turn it stands in and one either side.
        func around(_ values: [Double], near value: Double) -> [Double] {
            guard let period else { return values }

            let turn = ((value - low) / period).rounded(.down)
            return [turn - 1, turn, turn + 1].flatMap { turn in values.map { $0 + turn * period } }
        }

        /// Where the axis in focus comes to rest from `value` once let go: the snap nearest - a turn on or back where
        /// it comes round - or, with none, `value` itself, inside the range of an axis that does not come round.
        /// Design: docs/design/views/phase-layout.md#coming-to-rest
        func resting(at value: Double) -> Double {
            guard stops.isEmpty else { return nearest(value) }

            return period == nil ? min(max(value, low), high) : value
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

        /// Places every view where the arithmetic says - a change of the description on its way from where each view
        /// was shown - again next frame while it goes on.
        /// Design: docs/design/views/phase-layout.md#the-run
        func place(at now: Double, reducesMotion: Bool) -> EngineAnswer {
            let room = states.room.wrappedValue

            // Where the hands hold the run is the phase's value, for whatever follows it.
            phase.journey.show(holding(phase.journey.walked), by: ObjectIdentifier(states.held.storage))

            // A room not yet measured places nothing: every view stands in the whole of it until it is.
            guard room.width > 0, room.height > 0 else {
                states.placements.wrappedValue = PlacedRun()
                return .wait
            }

            // A change of the description or of where the motion set out is measured before the run is worked
            // out where it stands now.
            let phase = live()
            let from = setOut(at: phase)
            let memory = changed(at: now, from: from, reducesMotion: reducesMotion)
            let poses = pose(in: Rect(0, 0, room.width, room.height), at: phase, from: from)
            let changing = show(
                poses, after: memory, at: now, phase: phase, from: from, room: room, reducesMotion: reducesMotion)
            return changing ? .again : .wait
        }

        /// Where the run's motion set out, the run standing at `phase`: there, where nothing moves it - no hand, no
        /// throw, the phase where it is going - and kept while something does, until it passes a target on the
        /// hand's axis: the motion sets out from the last it passed, either way.
        /// Design: docs/design/views/phase-layout.md#where-a-motion-set-out
        func setOut(at phase: Phase) -> Phase {
            let journey = self.phase.journey
            let resting = states.held.wrappedValue.isEmpty && journey.value == journey.destination
            var from = states.from.wrappedValue ?? phase
            if resting {
                from = phase
            } else {
                for hand in hands {
                    let run = on(hand)
                    guard let passed = run.passed(from: run.onAxis(from), to: run.onAxis(phase)) else { continue }
                    from = run.placing(passed, in: from)
                }
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

        /// Whether two places on the hand's axis are one, a logarithm's rounding apart.
        static func same(_ one: Double, _ other: Double) -> Bool {
            one == other || abs(one - other) <= 1e-9 * max(abs(one), abs(other), 1)
        }

        /// One view inside the holder the run places, so the author's own properties on the view are never
        /// overwritten by a frame of arithmetic; a shade is the holder's second child. Where its view is not, a
        /// holder lets input through to the layout.
        func wrapped(_ slot: Slot) -> AnyView {
            // With no shade and no tap, the holder is a view of its own: a new order carries every one.
            // Design: docs/design/views/phase-layout.md#a-view-in-its-holder
            if mask == nil, tapped == nil { return AnyView(node: holder(slot.item)) }

            let holder = Grid { BuiltViews(nodes: [make(slot.item)] + (mask.map { [$0] } ?? [])) }

            guard let tapped else { return AnyView(holder.letsInputThrough(true)) }

            let item = slot.item
            let tap: EventHandler = { try await tapped.run(item) }
            return switch tapped.gate {
            case .own(let policy): AnyView(holder.onTapped(policy, tap))
            case .shared(let gate): AnyView(holder.onTapped(gate: gate, tap))
            }
        }

        /// One placement a view: a run that answered fewer or more is said once and made to fit.
        func fitted(_ answered: [Placement]) -> [Placement] {
            guard answered.count != items.count else { return answered }

            complain("A PhaseLayout's placements answered \(answered.count) placements for \(items.count) views. "
                + "One placement a view, in the items' order: the rest stand at the top left, the extra go.")

            let missing = max(items.count - answered.count, 0)
            return Array(answered.prefix(items.count)) + Array(repeating: Placement(.zero), count: missing)
        }

        // MARK: - The hand

        /// The hand over the element, along the layout or - a pan - every way: each axis it moves goes with it, and
        /// let go they go on together, each with its part of the speed.
        /// Design: docs/design/views/phase-layout.md#a-pan
        func handMoved(_ gesture: GesturePhase, moved: Point, speed: Point) {
            let runs = hands.filter { $0.way != nil }.map(on)

            switch gesture {
            case .began, .changed:
                for run in runs { run.hand(gesture, moved: moved) }
            case .ended, .cancelled:
                letGo(together: runs.compactMap { run in run.thrown(gesture, speed: speed).map { (run, $0) } })
            }
        }

        /// A wheel's notches over the element: each axis the hand moves stepped as they turn its way.
        func stepped(_ notches: Point) {
            for hand in hands where hand.way != nil { on(hand).step(notches) }
        }

        /// The hand over the element on the axis in focus: it takes the run where it is shown, and moves the axis
        /// with it.
        /// Design: docs/design/views/phase-layout.md#the-hand
        func hand(_ gesture: GesturePhase, moved: Point) {
            switch gesture {
            case .began:
                take(at: onAxis(live()))
            case .changed:
                // A move with no beginning heard is one: the run is taken where it is shown.
                let held = self.held ?? take(at: onAxis(phase.journey.value))
                // A room not yet measured draws no view, so a hand over it moves none.
                guard let per = unit(at: held) else { return }

                move(by: -(across ? moved.x : moved.y) / per)
            case .ended, .cancelled:
                break
            }
        }

        /// The axis in focus moved `step` of its unit where the hand works on it - a magnification's logarithm -
        /// from where the hand holds it: less and less past an end of an axis that does not come round, no farther
        /// than a swipe reaches, each snap it passes named.
        func move(by step: Double) {
            let point = toHand(held ?? take(at: onAxis(phase.journey.value)))
            let (low, high) = (toHand(self.low), toHand(self.high))
            let free = fromHand(period != nil ? point + step
                : Self.given(Self.pulled(point, low: low, high: high) + step, low: low, high: high))
            let next = reach.map { min(max(free, $0.lowerBound), $0.upperBound) } ?? free

            held = next
            if !stops.isEmpty { name(nearest(next)) }
        }

        /// The hand in focus letting go at `speed`, per second: where it held the axis, the unit there, how fast it
        /// went and where its throw would end; nil where it held nothing.
        func thrown(_ gesture: GesturePhase, speed: Point) -> Letting? {
            guard let held else { return nil }

            let measured = unit(at: held)
            let per = measured ?? 1
            let thrown = gesture == .ended && measured != nil ? -(across ? speed.x : speed.y) / per : 0
            return letting(at: held, per: per, speed: thrown)
        }

        /// The axis in focus let go at `value`, going `speed` units a second where the hand works on it, a unit
        /// standing for `per` device units or degrees: where its throw would end - inside the range of an axis that
        /// does not come round, and where it was let go for a hand too slow to throw.
        func letting(at value: Double, per: Double, speed: Double) -> Letting {
            let point = toHand(value)
            let carried = abs(speed) * per >= Self.throwing ? point + Self.carried(speed, by: throwing) : point
            let end = period == nil ? min(max(carried, toHand(low)), toHand(high)) : carried
            return Letting(point: point, per: per, speed: speed, end: end)
        }

        /// Where the axis in focus comes to rest let go as `letting` says: a swipe thrown, the next snap of its reach
        /// that way; otherwise where the throw ends, onto the snap nearest it.
        func rest(of letting: Letting) -> Double {
            let thrown = abs(letting.speed) * letting.per >= Self.throwing ? letting.speed : 0
            return swiped(from: fromHand(letting.point), thrown: thrown) ?? resting(at: fromHand(letting.end))
        }

        /// The axes `lettings` holds let go at once: each named where it comes to rest, then the run going on there
        /// from where the hands left it as one journey of the phase on the host's channel - each axis setting out at
        /// its hand's speed - under the law the first axis going on takes.
        /// Design: docs/design/views/phase-layout.md#coming-onto-a-target
        func letGo(together lettings: [(run: Run, letting: Letting)]) {
            let start = live()
            let rests = lettings.map { $0.run.rest(of: $0.letting) }
            for ((run, _), rest) in zip(lettings, rests) {
                run.grip = nil
                run.name(rest)
            }
            let goings = zip(lettings, rests).compactMap { lettingRest in
                lettingRest.0.run.going(lettingRest.0.letting, to: lettingRest.1).map { (run: lettingRest.0.run, going: $0) }
            }
            for (run, _) in lettings { run.held = nil }
            guard let law = goings.first?.going.law else { return }

            let journey = phase.journey
            var velocity = journey.velocity
            for (run, going) in goings { velocity = run.placing(going.speed, in: velocity) }
            journey.value = start
            journey.velocity = velocity
            _ = journey.move(to: journey.destination, law)
        }

        /// How the axis in focus goes on to `value`, named there already, let go as `letting` says: thrown on to a
        /// snap ahead, from the hand's speed under the input's motion - its spring, else a glide no longer than twice
        /// its length - onto the next snap no slower than the layout's motion moves a unit; with no snaps, on to where
        /// its throw ends, always so; let go still, thrown back or slower than that, it approaches the target under
        /// that motion over as much of its length as the way left is of a unit. Its law, and its speed in units of the
        /// phase a second; nil where it stands there already, or has no law to go by.
        /// Design: docs/design/views/phase-layout.md#coming-onto-a-target
        func going(_ letting: Letting, to value: Double) -> (law: Motion, speed: Double)? {
            let along = toHand(value)
            let left = along - letting.point
            let motion = resolvedLaw
            let flight = Self.flight(left, at: letting.speed, by: throwing)
            let onward = stops.isEmpty || !next(from: fromHand(letting.point), to: value)
                || flight <= abs(left) * Double(motion.milliseconds)
            let isThrow = abs(letting.speed) * letting.per >= Self.throwing && left * letting.speed > 0 && onward

            guard abs(left) * letting.per > Self.settled, motion.kind != .custom || isThrow else { return nil }

            // The hand's speed as the phase goes: its axis's slope where it let go - a magnification's, by the scale.
            // An eased approach sets out on its own curve, never slower than the motion; a spring takes the hand's
            // speed toward the target.
            let speed = (fromHand(letting.point + letting.speed / 1_000) - fromHand(letting.point)) * 1_000
            guard isThrow else {
                let approach = Self.approach(motion, over: left)
                let springs = if case .spring = approach.kind { true } else { false }
                return (approach, springs && left * letting.speed > 0 ? speed : 0)
            }
            if case .spring = throwing.kind { return (throwing, speed) }
            let longest = max(Double(Self.timing(of: throwing).milliseconds) * 2, Self.shortest)
            return (.glide(within: .milliseconds(Int(longest.rounded()))), speed)
        }

        /// An axis letting go, where the hand works on it - a magnification's logarithm: where it held the run, how
        /// many device units or degrees a unit stands for, its speed in units a second, and where its throw ends.
        struct Letting {
            let point: Double
            let per: Double
            let speed: Double
            let end: Double
        }

        /// Two fingers over the element, a pinch and a rotation as one: each axis they move goes by its own input - a
        /// magnification by how far they spread, a rotation by how far they turned - and let go, they go on together
        /// to where each would end. A view held by itself keeps the hand.
        /// Design: docs/design/views/phase-layout.md#two-fingers
        func pinch(_ gesture: GesturePhase, scale: Double, degrees: Double, speed: Point) {
            guard states.item.wrappedValue == nil else { return }

            var lettings: [(run: Run, letting: Letting)] = []
            for hand in hands {
                // How far the fingers moved the axis, how fast in units a second, and how many of theirs a unit is.
                let (step, rate, per): (Double, Double, Double)
                switch hand.gesture {
                case .magnification: (step, rate, per) = (scale > 0 ? log(scale) : 0, speed.x, 100)
                case .rotation(let unit): (step, rate, per) = (degrees / unit, speed.y / unit, unit)
                case .hand: continue
                }

                let run = on(hand)
                switch gesture {
                case .began:
                    run.take(at: run.onAxis(live()))
                case .changed:
                    run.move(by: step)
                case .ended, .cancelled:
                    guard let held = run.held else { continue }
                    lettings.append((run, run.letting(at: held, per: per, speed: gesture == .ended ? rate : 0)))
                }
            }
            if !lettings.isEmpty { letGo(together: lettings) }
        }

        /// Where the hand stands for the run at `point`, the ends at `low` and `high`: past one, as far beyond it as
        /// the hand went for the run to give that much.
        static func pulled(_ point: Double, low: Double, high: Double) -> Double {
            point > high ? high + pulled(point - high) : point < low ? low - pulled(low - point) : point
        }

        /// Where the run stands for the hand at `point`, the ends at `low` and `high`: past one, less and less of the
        /// way beyond it.
        static func given(_ point: Double, low: Double, high: Double) -> Double {
            point > high ? high + given(point - high) : point < low ? low - given(low - point) : point
        }

        /// Whether `to` is the next target from `from` on the hand's axis: none stands between them.
        func next(from: Double, to: Double) -> Bool {
            !around(stops, near: from).contains { min(from, to) < $0 && $0 < max(from, to) }
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
        /// Design: docs/design/views/phase-layout.md#the-hand
        func unit(at value: Double) -> Double? {
            switch travel {
            case .points(let points):
                return points
            case .room:
                let room = states.room.wrappedValue
                guard room.width > 0, room.height > 0 else { return nil }
                return across ? room.width : room.height
            case .front:
                if swipes, let grip { return grip.unit }
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

            let here = pose(in: room, at: placing(value, in: shown), from: from)
            let before = pose(in: room, at: placing(value - Self.probe, in: shown), from: from)
            let after = pose(in: room, at: placing(value + Self.probe, in: shown), from: from)
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

        /// A wheel's notches over the element: the run goes on from where the axis in focus is going - its journey's
        /// end, a throw's too - to the snap as many on as the notches turned, or, with none, as far as a hand going a
        /// notch's travel for each moves it, under the layout's motion. A swipe's go one snap from where the run
        /// rests, and wait while it goes. A hand holding the run keeps it.
        /// Design: docs/design/views/phase-layout.md#a-wheels-notch
        func step(_ notches: Point) {
            let count = Int((-(across ? notches.x : notches.y)).rounded())
            guard count != 0 else { return }
            guard held == nil else { return }

            let journey = phase.journey
            if swipes {
                guard journey.value == journey.destination else { return }
            }
            let start = live()
            let from = onAxis(journey.destination)
            let along = stops.isEmpty ? notched(from, by: count) : stepped(from, by: swipes ? count.signum() : count)

            held = nil
            send(to: placing(along, in: journey.destination), from: start, speed: 0)
        }

        /// The snap `count` on from the one nearest `value` - back for fewer than nought - held to the ends of a run
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

        /// Where `count` notches take an axis with no snaps from `value`: as far as a hand going `notch` device units
        /// for each moves it, inside the range of an axis that does not come round.
        func notched(_ value: Double, by count: Int) -> Double {
            let moved = value + Double(count) * Self.notch / (unit(at: value) ?? Self.notch)
            return period == nil ? min(max(moved, low), high) : moved
        }

        /// How far a wheel's notch moves an axis with no snaps, in device units.
        static var notch: Double { 100 }

        /// The run taken by the hand at `value` on its axis: a journey under way - a throw's too - stops there. A swiping
        /// hand grips it at the target nearest, with the unit the run would have standing there.
        @discardableResult
        func take(at value: Double) -> Double {
            held = value
            if swipes {
                let target = nearest(value)
                let resting = placing(target, in: phase.journey.value)
                let unit = travel == .front ? measured(at: target, from: resting) : unit(at: target)
                grip = LayoutGrip(target: target, unit: unit)
            }
            name(nearest(value))
            return value
        }

        /// How far a swiping hand moves the run on its axis: from the target before the one it took it at to the
        /// one after; nil for a scroll.
        /// Design: docs/design/views/phase-layout.md#a-swipe
        var reach: ClosedRange<Double>? {
            guard swipes, let grip else { return nil }

            return stepped(grip.target, by: -1)...stepped(grip.target, by: 1)
        }

        /// Where a swipe let go at `held` comes to rest: thrown, the next of its reach's targets that way - where it
        /// took the run or the one beyond; let go still, the nearest of them. Nil for a scroll.
        /// Design: docs/design/views/phase-layout.md#a-swipe
        func swiped(from held: Double, thrown: Double) -> Double? {
            guard let reach, let grip else { return nil }

            let targets = [reach.lowerBound, grip.target, reach.upperBound]
            guard thrown != 0 else { return nearest(of: targets, to: held) }

            let ahead = targets.filter { thrown > 0 ? $0 > held : $0 < held }
            return (thrown > 0 ? ahead.min() : ahead.max()) ?? nearest(of: targets, to: held)
        }

        /// How much farther a throw at `speed` units a second carries under `throwing`: eased, the hand's speed for
        /// its length over how steeply its curve sets out; a spring, for a third of its response - as far as a
        /// `cubicOut` of that length.
        static func carried(_ speed: Double, by throwing: Motion) -> Double {
            let timing = timing(of: throwing)
            let length = Double(timing.milliseconds) / 1_000

            return speed * length / setsOut(timing)
        }

        /// The law a throw is timed by: its own, the inherited one 400 milliseconds on `cubicOut`.
        static func timing(of throwing: Motion) -> Motion {
            throwing.kind == .inherited ? .eased(.milliseconds(400)) : throwing
        }

        /// How steeply a throw under `timing` sets out: eased, its curve's first slope; a spring, as a `cubicOut`
        /// of its response does.
        static func setsOut(_ timing: Motion) -> Double {
            if case .spring = timing.kind { return 3 }
            return max(HostMotionLaw.slope(easing(of: timing), at: 0), 0.1)
        }

        /// The easing a throw under `motion` sets out by where it is eased: its own, `cubicOut` for a motion with none.
        static func easing(of motion: Motion) -> Easing {
            if case .eased(_, let curve) = motion.kind { return curve }
            return .cubicOut
        }

        /// How long a throw at `speed` units a second takes to go `left` on under `throwing`, in milliseconds: the
        /// length that sets it out at the hand's speed - a spring's as a `cubicOut` of its response would - never
        /// shorter than `shortest`, nor longer than twice the motion's length.
        static func flight(_ left: Double, at speed: Double, by throwing: Motion) -> Double {
            let timing = timing(of: throwing)
            let length = Double(timing.milliseconds)
            let setting = speed == 0 ? .infinity : abs(left / speed) * setsOut(timing) * 1_000

            return min(max(setting, shortest), max(length * 2, shortest))
        }

        /// The layout's `motion` for an approach `left` units long, a unit a length: eased, as long as the way left
        /// takes; a spring, its response cut alike.
        static func approach(_ motion: Motion, over left: Double) -> Motion {
            let length = Duration.milliseconds(Int((abs(left) * Double(motion.milliseconds)).rounded()))

            switch motion.kind {
            case .eased(_, let curve): return .eased(length, curve)
            case .spring(_, let damping): return .spring(response: length, damping: damping)
            case .glide: return .glide(within: length)
            case .inherited, .none, .custom: return .none
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

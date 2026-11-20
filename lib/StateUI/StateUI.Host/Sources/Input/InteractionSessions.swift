// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIFoundation
@_spi(Host) import StateUI

/// The hands holding numbers of states, for every view and window of a runtime: one hand a number, each shown in
/// its state's channel where its hand holds it and sent on from there let go.
/// Design: docs/design/host/interaction.md#the-hold
@_spi(Host) @MainActor public final class InteractionSessions {
    /// One number of a state: its channel and its lane.
    struct Lane: Hashable {
        let state: Int32
        let lane: Int
    }

    /// One number held: whose hand, where it holds it, and - a swipe - the snap it took it at with the unit it
    /// moves it by.
    private struct Hold {
        let mount: UInt64
        weak var element: MountedElement?
        var value: Double
        var grip: (target: Double, unit: Double?)?
    }

    /// What of the hand a gesture is: one hand, or two fingers.
    private enum Stream { case hand, fingers }

    private let channels: StateChannels
    private let now: () -> Double
    private let reducesMotion: () -> Bool

    /// Every number held, and the gestures a program's write took the numbers from, by their element's mount:
    /// what such a gesture says until it ends moves nothing.
    private var held: [Lane: Hold] = [:]
    private var lost: [UInt64: Set<Stream>] = [:]

    /// Sessions writing `channels`, on the clock `now`.
    public init(channels: StateChannels, now: @escaping () -> Double, reducesMotion: @escaping () -> Bool) {
        self.channels = channels
        self.now = now
        self.reducesMotion = reducesMotion
        channels.interrupts = { [weak self] state, lanes in self?.interrupted(state, lanes) }
    }

    /// Whether a hand holds a number through `element`.
    public func holds(_ element: MountedElement) -> Bool {
        held.values.contains { $0.mount == element.mount }
    }

    // MARK: - One hand

    /// The hand over `element` at `phase`, having moved what is under it by `moved` since its last report, lifting
    /// at `speed` a second - both as the element's run reads them: each number it moves goes with it, and let go
    /// they go on together.
    /// Design: docs/design/host/interaction.md#the-hold
    public func hand(_ phase: GesturePhase, moved: Point, speed: Point, on element: MountedElement) {
        let axes = axes(of: element) { if case .translation = $0 { true } else { false } }
        guard !axes.isEmpty else { return }

        // What a toolkit tells as no number moves nothing.
        let (moved, speed) = (Self.told(moved), Self.told(speed))
        switch phase {
        case .began:
            lost[element.mount]?.remove(.hand)
            show(axes.compactMap { axis in take(axis, on: element).map { (axis, $0) } })
        case .changed:
            guard lost[element.mount]?.contains(.hand) != true else { return }

            var shown: [(InteractionAxis, Double)] = []
            for axis in axes {
                // A move with no beginning heard is one: the number is taken where it stands.
                guard let value = mine(axis, on: element)?.value ?? take(axis, on: element),
                      // A room not yet measured draws no view, so a hand over it moves none.
                      let per = unit(of: axis, at: value, on: element)
                else { continue }

                shown.append((axis, move(axis, by: axis.sense * (axis.across ? moved.x : moved.y) / per)))
            }
            show(shown)
        case .ended, .cancelled:
            lost[element.mount]?.remove(.hand)
            letGo(axes.compactMap { axis in
                guard let hold = mine(axis, on: element) else { return nil }

                let measured = unit(of: axis, at: hold.value, on: element)
                let per = measured ?? 1
                let thrown = phase == .ended && measured != nil
                    ? axis.sense * (axis.across ? speed.x : speed.y) / per : 0
                return (axis, axis.letting(at: hold.value, per: per, velocity: thrown))
            }, on: element)
        }
    }

    /// A wheel's whole notches over `element`, as its run reads them: each number the hand moves goes on from where
    /// it is going to the snap as many on, or - with no snaps - as far as a hand going a notch's travel for each
    /// moves it, under its state's own motion. A swipe's go one snap, and wait while it travels; a number a hand
    /// holds keeps it.
    /// Design: docs/design/host/interaction.md#a-wheels-notch
    public func notches(_ notches: Point, on element: MountedElement) {
        var sent: [Int32: [ReleasedLane]] = [:]
        for axis in axes(of: element, where: { if case .translation = $0 { true } else { false } }) {
            let lane = Lane(state: axis.value.state, lane: axis.value.lane)
            let turned = axis.sense * (axis.across ? notches.x : notches.y)
            guard turned.isFinite, abs(turned) < 1e6, held[lane] == nil,
                  let standing = channels.standing(lane.state, now: now()),
                  standing.value.indices.contains(lane.lane)
            else { continue }

            let count = Int(turned.rounded())
            let (value, going) = (standing.value[lane.lane], standing.destination[lane.lane])
            guard count != 0, !axis.swipes || value == going else { continue }

            let along = axis.hasSnaps
                ? axis.stepped(going, by: axis.swipes ? count.signum() : count)
                : axis.notched(going, by: count, per: unit(of: axis, at: going, on: element))
            let there = going == along
                && abs(value - along) * (unit(of: axis, at: along, on: element) ?? 1) <= InteractionArithmetic.settled
            sent[lane.state, default: []].append(ReleasedLane(
                lane: lane.lane, from: there ? along : value, destination: along,
                velocity: there ? 0 : standing.velocity[lane.lane]))
        }
        for state in sent.keys.sorted() {
            channels.release(state, sent[state] ?? [], now: now(), reducesMotion: reducesMotion())
        }
    }

    // MARK: - Two fingers

    /// Two fingers over `element` at `phase`, a pinch and a rotation as one: since their last report they spread
    /// by `scale` and turned `degrees`; lifting, they go at `speed` a second - the scale's logarithm across, the
    /// degrees down. Each number they move goes by its own input, and let go they go on together.
    /// Design: docs/design/host/interaction.md#two-fingers
    public func fingers(
        _ phase: GesturePhase, scale: Double, degrees: Double, speed: Point, on element: MountedElement
    ) {
        let axes = axes(of: element) { if case .translation = $0 { false } else { true } }
        guard !axes.isEmpty else { return }
        if phase == .began || phase == .ended || phase == .cancelled { lost[element.mount]?.remove(.fingers) }
        guard phase != .changed || lost[element.mount]?.contains(.fingers) != true else { return }

        let (scale, degrees, speed) = (scale.isFinite && scale > 0 ? scale : 1, degrees.isFinite ? degrees : 0, Self.told(speed))
        var shown: [(InteractionAxis, Double)] = []
        var lettings: [(InteractionAxis, InteractionAxis.Letting)] = []
        for axis in axes {
            // How far the fingers moved the number, how fast in units a second, and how many of theirs a unit is.
            let (step, rate, per): (Double, Double, Double)
            switch axis.value.input {
            case .magnification:
                (step, rate, per) = (axis.sense * (scale > 0 ? log(scale) : 0), axis.sense * speed.x, 100)
            case .rotation(let unit):
                (step, rate, per) = (axis.sense * degrees / unit, axis.sense * speed.y / unit, unit)
            case .translation:
                continue
            }

            switch phase {
            case .began:
                if let value = take(axis, on: element) { shown.append((axis, value)) }
            case .changed:
                guard mine(axis, on: element) != nil || take(axis, on: element) != nil else { continue }
                shown.append((axis, move(axis, by: step)))
            case .ended, .cancelled:
                guard let hold = mine(axis, on: element) else { continue }
                lettings.append((axis, axis.letting(at: hold.value, per: per, velocity: phase == .ended ? rate : 0)))
            }
        }
        show(shown)
        letGo(lettings, on: element)
    }

    /// The point a toolkit told, each coordinate that is no finite number nought.
    private static func told(_ point: Point) -> Point {
        Point(x: point.x.isFinite ? point.x : 0, y: point.y.isFinite ? point.y : 0)
    }

    // MARK: - The hold

    /// The numbers of `element`'s program an input `moved` by answers for.
    private func axes(of element: MountedElement, where moved: (HostInteractionInput) -> Bool) -> [InteractionAxis] {
        element.interactionProgram?.values.filter { moved($0.input) }.map(InteractionAxis.init) ?? []
    }

    /// The hold `element`'s hand has on `axis`'s number; nil where it has none.
    private func mine(_ axis: InteractionAxis, on element: MountedElement) -> Hold? {
        guard let hold = held[Lane(state: axis.value.state, lane: axis.value.lane)], hold.mount == element.mount
        else { return nil }
        return hold
    }

    /// `element`'s hand takes `axis`'s number where the last frame showed it - a run under way stops there for it,
    /// so what the user pressed stays under the hand - and
    /// a swiping hand grips it at the snap nearest, with the unit the number would have resting there. Where it
    /// took it; nil for a number another view's hand holds, or one nothing shows.
    private func take(_ axis: InteractionAxis, on element: MountedElement) -> Double? {
        let lane = Lane(state: axis.value.state, lane: axis.value.lane)
        if let other = held[lane], other.mount != element.mount { return nil }
        guard let standing = channels.standing(lane.state), standing.value.indices.contains(lane.lane)
        else { return nil }

        var hold = Hold(mount: element.mount, element: element, value: standing.value[lane.lane], grip: nil)
        if axis.swipes {
            let target = axis.nearest(hold.value)
            let unit = axis.unit == .frontItem
                ? element.layoutProgram?.frontItemUnit?(lane.lane, target, axis.across, true)
                : self.unit(of: axis, at: target, on: element)
            hold.grip = (target, unit)
        }
        held[lane] = hold
        element.layoutProgram?.handHolds(true)
        return hold.value
    }

    /// The number of `axis` moved `step` of its unit where the hand works on it, from where its hand holds it;
    /// where it stands now.
    private func move(_ axis: InteractionAxis, by step: Double) -> Double {
        let lane = Lane(state: axis.value.state, lane: axis.value.lane)
        guard var hold = held[lane] else { return 0 }

        hold.value = axis.moved(from: hold.value, by: step, within: hold.grip.map { axis.reach(about: $0.target) })
        held[lane] = hold
        return hold.value
    }

    /// Shows each number where its hand holds it, bound for where it would rest let go there: one word a state.
    private func show(_ values: [(axis: InteractionAxis, value: Double)]) {
        var lanes: [Int32: (lanes: [HeldLane], defers: Bool)] = [:]
        for (axis, value) in values {
            lanes[axis.value.state, default: ([], false)].lanes.append(
                HeldLane(lane: axis.value.lane, value: value, destination: axis.resting(at: value)))
            if axis.value.programWrites == .deferLatest { lanes[axis.value.state]?.defers = true }
        }
        for state in lanes.keys.sorted() {
            guard let said = lanes[state] else { continue }
            channels.hold(state, said.lanes, defers: said.defers)
        }
    }

    /// How far the hand travels for one unit of `axis`'s number at `value`, in points: the input's points, the
    /// element's length along the hand's way, or as far as its layout's front view goes for a unit - a swipe's,
    /// as measured where it took the number. Nil where there is nothing to measure yet.
    /// Design: docs/design/host/interaction.md#the-unit
    private func unit(of axis: InteractionAxis, at value: Double, on element: MountedElement) -> Double? {
        switch axis.unit {
        case .points(let points)?:
            return points
        case .containerLength?:
            guard let room = element.laidOutRoom, room.width > 0, room.height > 0 else { return nil }
            return axis.across ? room.width : room.height
        case .frontItem?:
            if axis.swipes, let grip = mine(axis, on: element)?.grip { return grip.unit }
            return element.layoutProgram?.frontItemUnit?(axis.value.lane, value, axis.across, false)
        case nil:
            return nil
        }
    }

    // MARK: - Letting go

    /// The numbers `lettings` holds let go at once: each bound for where it comes to rest, then on there from where
    /// the hand left it - one run a state, each number setting out at its hand's speed, under one law whatever
    /// order they were declared in: a throw's where one is thrown, else the approach of the longest way. A number
    /// that stays, or stands there already, rests there at once.
    /// Design: docs/design/host/interaction.md#letting-go
    private func letGo(_ lettings: [(axis: InteractionAxis, letting: InteractionAxis.Letting)], on element: MountedElement) {
        guard !lettings.isEmpty else { return }

        for state in Set(lettings.map(\.axis.value.state)).sorted() {
            let own = channels.standing(state, now: now())?.motion ?? .none
            var released: [ReleasedLane] = []
            var goings: [InteractionAxis.Going] = []
            for (axis, letting) in lettings where axis.value.state == state {
                let lane = Lane(state: state, lane: axis.value.lane)
                let rest = axis.rest(of: letting, grip: held[lane]?.grip?.target)
                held[lane] = nil
                if !axis.stays, let going = axis.going(letting, to: rest, under: own) {
                    goings.append(going)
                    released.append(ReleasedLane(
                        lane: lane.lane, from: axis.fromHand(letting.point), destination: rest, velocity: going.velocity))
                } else {
                    released.append(ReleasedLane(lane: lane.lane, from: rest, destination: rest, velocity: 0))
                }
            }
            let law = (goings.first { $0.thrown } ?? goings.max { abs($0.left) < abs($1.left) })?.law
            channels.release(state, released, under: law, now: now(), reducesMotion: reducesMotion())
        }
        if !holds(element) { element.layoutProgram?.handHolds(false) }
    }

    /// The numbers held at `lanes` go onto where their channels say they are going, with no speed, under their
    /// states' own motion: a hand taken away, not one that let go.
    private func cancel(_ lanes: [Lane]) {
        var released: [Int32: [ReleasedLane]] = [:]
        for lane in lanes.sorted(by: { ($0.state, $0.lane) < ($1.state, $1.lane) }) {
            guard let hold = held.removeValue(forKey: lane),
                  let standing = channels.standing(lane.state, now: now()),
                  standing.destination.indices.contains(lane.lane)
            else { continue }

            released[lane.state, default: []].append(ReleasedLane(
                lane: lane.lane, from: hold.value, destination: standing.destination[lane.lane], velocity: 0))
        }
        for state in released.keys.sorted() {
            channels.release(state, released[state] ?? [], now: now(), reducesMotion: reducesMotion())
        }
    }

    // MARK: - A hand taken away

    /// A write of the program names `lanes` of `state`, held by hands that do not wait for it: each such hand's
    /// gesture ends there - the numbers written are the program's, its other numbers go onto where they were
    /// going - and what the gesture says until it ends moves nothing.
    /// Design: docs/design/host/interaction.md#a-write-of-the-program
    private func interrupted(_ state: Int32, _ lanes: [Int]) {
        let written = Set(lanes.map { Lane(state: state, lane: $0) })
        let mounts = Set(written.compactMap { held[$0]?.mount })
        for mount in mounts.sorted() {
            let element = held.values.first { $0.mount == mount }?.element
            lost[mount] = [.hand, .fingers]
            for lane in written where held[lane]?.mount == mount { held[lane] = nil }
            cancel(held.filter { $0.value.mount == mount }.map(\.key))
            element?.layoutProgram?.handHolds(false)
        }
    }

    /// `element`'s program changed from `old`: a number its hand holds that the program moves no longer, or by
    /// another input, is let go as a hand taken away - the others stay under the hand, whatever else of them changed.
    /// Design: docs/design/host/interaction.md#a-program-described-again
    public func programChanged(on element: MountedElement, from old: HostInteractionProgram?) {
        let moved = element.interactionProgram?.values ?? []
        let gone = held.filter { lane, hold in
            guard hold.mount == element.mount else { return false }

            let before = old?.values.first { $0.state == lane.state && $0.lane == lane.lane }?.input
            return !moved.contains { $0.state == lane.state && $0.lane == lane.lane && $0.input == before }
        }.map(\.key)
        guard !gone.isEmpty else { return }

        cancel(gone)
        if !holds(element) { element.layoutProgram?.handHolds(false) }
    }

    /// The element mounted as `mount` left the tree: what its hand held is let go, as a hand taken away.
    public func left(_ mount: UInt64) {
        lost[mount] = nil
        cancel(held.filter { $0.value.mount == mount }.map(\.key))
    }
}

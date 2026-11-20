// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a motion layout's body hands its engine and its handlers: the arithmetic run on the host's frames, where its
// motion set out, and how far its front view goes for a unit - what the host's hand asks.
// Design: docs/design/views/motion-layout.md#the-run

import StateUIFoundation

extension MotionLayout {
    /// One axis the run works on: its place in the parameters' `axes` and the axis; which way a hand moves it and
    /// how it goes on let go, where one does; and as the layout maps it - where the arithmetic is asked, lowest
    /// first, the ends included, nil for every frame - the mapping's own range, and where its segments begin.
    /// Design: docs/design/views/interaction.md#on-a-motion-layout
    struct Hand {
        /// A mapping's range, and how far one turn takes it where it comes round.
        struct Span {
            let low: Double
            let high: Double
            let period: Double?
        }

        let index: Int
        let axis: WritableKeyPath<Parameters, Double>
        let way: Orientation?
        let release: InteractionRelease
        let knots: [Double]?
        let span: Span?
        let segments: [Double]
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
        let arithmetic: @MainActor (Rect, Parameters, Parameters) -> [Placement]

        /// The curve between the poses at keyframes, whether the arithmetic reads where the motion set out, the
        /// poses kept for this description, and the states the arithmetic follows, whose writes let them go.
        let curve: any LayoutInterpolation
        let readsFrom: Bool
        let kept: LayoutPoses
        let followed: [any FollowedState]

        let mask: Node?
        let path: KeyPath<Items.Element, ID>
        let activated: [ValueHandler<ID>]
        let named: ((Parameters) -> Void)?
        let dragged: [ValueHandler<ItemDrag<ID>>]
        let dismissals: [ValueHandler<ID>]

        /// The parameters the element wears: the author's, or the layout's own.
        let parameters: Binding<Parameters>
        let states: States

        /// Every axis the hand and the fingers move, and the one the run works on: the first the hand moves unless
        /// `on(_:)` says another.
        let hands: [Hand]
        var focus: Hand?

        /// How the views come onto their places as the layout itself was told (`layoutBodies(_:)`) - what a
        /// dismissed view's flight is timed by; and the body the view at an index says it is itself - nil for one
        /// that says none.
        let viewsBody: LayoutBody
        let body: @MainActor (Int) -> LayoutBody?

        /// The view at an index was built again: its body is read anew.
        let rebuilt: @MainActor (Int) -> Void

        /// What is told once the run comes to rest.
        let settled: [ValueHandler<Parameters>]

        /// The layout's own size in a room offered, at given parameters, where it says one.
        let sized: (@MainActor (Double?, Double?, Parameters) -> LayoutSize)?

        /// The run working on `hand`'s axis.
        func on(_ hand: Hand) -> Run {
            var run = self
            run.focus = hand
            return run
        }

        /// The axis in focus, and whether a hand moves it across.
        var axis: WritableKeyPath<Parameters, Double>? { focus?.axis }
        var across: Bool { focus?.way != .vertical }

        // MARK: - The parameters

        /// `parameters` with the hand's axis at `value`, the other axes as they are.
        func placing(_ value: Double, in parameters: Parameters) -> Parameters {
            guard let axis else { return parameters }

            var placed = parameters
            placed[keyPath: axis] = value
            return placed
        }

        /// The parameters as they stand this frame: where the host's channel shows them - under the hand, where a
        /// hand holds them.
        /// Design: docs/design/views/motion-layout.md#the-parameters
        func live() -> Parameters {
            parameters.journey.walked
        }

        // MARK: - On the cycle

        /// Tells whoever keeps a value of its own by the parameters where they are going, once that changed since
        /// the last frame - the hand naming a snap, or the program writing them: nothing of the way there.
        /// Design: docs/design/views/motion-layout.md#a-target-named
        func tellNamed() {
            guard let named else { return }

            let going = parameters.journey.going
            let told = states.lastNamed.wrappedValue
            guard told != going else { return }

            states.lastNamed.wrappedValue = going
            // The first frame learns where the parameters stand: nobody is told what nobody changed.
            if told != nil { named(going) }
        }

        /// One view inside the holder the run places, so the author's own properties on the view are never
        /// overwritten by a frame of arithmetic; a shade is the holder's second child. Where its view is not, a
        /// holder lets input through to the layout.
        func wrapped(_ slot: Slot) -> AnyView {
            // With no shade and no activation, the holder is a view of its own: a new order carries every one.
            // Design: docs/design/views/motion-layout.md#a-view-in-its-holder
            if mask == nil, activated.isEmpty {
                rebuilt(slot.index)
                return AnyView(node: holder(slot.item))
            }

            let holder = Grid { BuiltViews(nodes: [built(slot)] + (mask.map { [$0] } ?? [])) }

            guard !activated.isEmpty else { return AnyView(holder.letsInputThrough(true)) }

            let id = slot.item[keyPath: path]
            var tapped = AnyView(holder)
            for activated in activated {
                let tap: EventHandler = { try await activated.run(id) }
                tapped = switch activated.gate {
                case .own(let policy): AnyView(tapped.onTapped(policy: policy, tap))
                case .shared(let gate): AnyView(tapped.onTapped(gate: gate, tap))
                }
            }
            return tapped
        }

        /// The view of `slot`, built now - again where a state it reads moved, the holder around it standing: its
        /// body is read anew the next time a frame asks.
        func built(_ slot: Slot) -> Node {
            rebuilt(slot.index)
            return make(slot.item)
        }

        /// One placement a view, every number of it finite: a run that answered fewer or more, or a number that is
        /// not finite, is said once and made to fit.
        /// Design: docs/design/views/motion-layout.md#an-answer-made-to-fit
        func fitted(_ answered: [Placement]) -> [Placement] {
            let finite = answered.map(Self.finite)
            guard finite.count != items.count else { return finite }

            complain("A MotionLayout's placements answered \(answered.count) placements for \(items.count) views. "
                + "One placement a view, in the items' order: the rest stand at the top left, the extra go.")

            let missing = max(items.count - finite.count, 0)
            return Array(finite.prefix(items.count)) + Array(repeating: Placement(.zero), count: missing)
        }

        /// `placement` with each number that is not finite the one a placement at the top left holds, said once;
        /// a placement whose every number is finite - every frame's - is looked at and handed on as it is.
        private static func finite(_ placement: Placement) -> Placement {
            let (bounds, turn) = (placement.bounds, placement.transform)
            let isFinite = bounds.x.isFinite && bounds.y.isFinite && bounds.width.isFinite && bounds.height.isFinite
                && turn.a.isFinite && turn.b.isFinite && turn.c.isFinite && turn.d.isFinite && turn.tx.isFinite
                && turn.ty.isFinite && placement.opacity.isFinite && placement.shade.isFinite
            guard !isFinite else { return placement }
            complain("A MotionLayout's placements answered a number that is not finite - a division by nothing, an "
                + "infinity: each stands as a placement at the top left holds it.")
            let neutral = Placement(.zero)
            func held(_ number: Double, _ standIn: Double) -> Double { number.isFinite ? number : standIn }
            return Placement(
                Rect(x: held(bounds.x, 0), y: held(bounds.y, 0), width: held(bounds.width, 0), height: held(bounds.height, 0)),
                transform: ViewTransform(
                    x: held(turn.x, 0), y: held(turn.y, 0), rotation: held(turn.rotation, 0),
                    width: held(turn.width, 1), height: held(turn.height, 1)),
                opacity: held(placement.opacity, neutral.opacity),
                shade: held(placement.shade, neutral.shade),
                zIndex: placement.zIndex)
        }

        // MARK: - The front view

        /// How far the view drawn in front of those the parameters move goes for one unit of the hand's axis at
        /// `value`, the motion setting out from `from`; a room's length where nothing moves, none where the room is not
        /// measured yet.
        func measured(at value: Double, from: Parameters) -> Double? {
            let laid = states.room.wrappedValue
            guard laid.width > 0, laid.height > 0 else { return nil }

            let room = Rect(x: 0, y: 0, width: laid.width, height: laid.height)
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

        /// How far either side of where the run stands the view in front is measured, in units of the parameters.
        static var probe: Double { 0.01 }
    }
}

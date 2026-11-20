// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What the user's hand does to the element's own presentation: its press's offset, asked of the application's
/// effect once a frame, and its drag's hold, pinned to the hand.
/// Design: docs/design/host/interaction.md#a-views-own-press-and-drag
extension MountedElement {
    /// How the hand takes the view by itself, where it does.
    public var handDrag: HostDrag? { interactionProgram?.drag }

    /// The layout program that places the view, by the element running it, and the view's place among its
    /// children: the element's own parent - or, the element standing first in a holder that lets input through,
    /// the holder's, as a motion layout stands each of its views.
    /// Design: docs/design/host/interaction.md#a-layouts-view-in-the-hand
    var programPlacing: (layout: MountedElement, place: Int)? {
        guard let parent else { return nil }

        var placed = self
        if parent.layoutProgram == nil {
            guard parent.bool(.letsInputThrough) == true, parent.children.first === self else { return nil }
            placed = parent
        }
        guard let layout = placed.parent, layout.layoutProgram != nil,
              let place = layout.children.firstIndex(where: { $0 === placed })
        else { return nil }
        return (layout, place)
    }

    /// The element in whose view a hand over this one is measured - a space the hand itself does not move: the
    /// layout whose program places the view, else its parent. A view the hand takes moves under it, and a move
    /// measured in the view itself would shrink as the view came after it.
    /// Design: docs/design/host/interaction.md#where-the-hand-is-measured
    public var handSpace: MountedElement? { programPlacing?.layout ?? parent }

    /// What the hand does to the view the element is as a layout program's child: its own, or - a holder that
    /// lets input through - its view's.
    var placedLocal: LocalPresentation {
        guard local.isIdle, bool(.letsInputThrough) == true, let view = children.first else { return local }
        return view.local
    }

    /// Whether the hand holds the view the element is as a layout program's child by itself.
    var holdsPlacedView: Bool {
        handReading.holdsView || (bool(.letsInputThrough) == true && children.first?.handReading.holdsView == true)
    }

    /// The view's own press at `phase`, standing at `point` of a view `size` large: kept for the next frame, which
    /// asks its effect.
    func pressedLocally(_ phase: GesturePhase, at point: Point, size: LayoutSize, in runtime: HostRuntime) {
        guard interactionProgram?.press != nil || pressReading.isDown else { return }

        // A layout program moves the view it holds by its place, which moves no point of the view itself.
        var drawn = local
        if programPlacing != nil { drawn.held = nil }
        pressReading.told(phase, at: drawn.placed(point, in: size), size: size, time: runtime.clock.now())
        if pressReading.waiting != nil { runtime.handPace.opened(self) }
    }

    /// A frame: the press that waited is asked of its effect, and what it answers - the numbers the press names -
    /// is what the view is bound for; a press lifted or taken away, or one the view answers no longer, binds it
    /// for its place. What is laid over the view comes after that on the press's own spring, where it has one.
    /// Design: docs/design/host/interaction.md#a-press-with-a-spring-of-its-own
    func pacedLocally(in runtime: HostRuntime) {
        let now = runtime.clock.now()
        if let press = pressReading.taken() {
            let ends = press.phase == .ended || press.phase == .cancelled
            let answered = interactionProgram?.press.flatMap { ends ? nil : $0.effect.offset(press).kept($0.values) }
            let spring = runtime.reducesMotion() ? nil : interactionProgram?.press?.spring
            localFollow.aim(at: answered ?? .identity, on: spring, now: now)
        }
        present(pressed: localFollow.step(to: now), in: runtime)
        if localFollow.moves { runtime.handPace.opened(self) }
    }

    /// The spring a view no layout program places comes back on once the hand lets it go: the body it says
    /// itself, else its layout's for every child; nil for a view that is at its place at once.
    private var bodyOfItsOwn: HostLayoutBody? {
        let own = value(ViewContract.layoutBody.token).flatMap(LayoutBody.init(propValue:))
        let layouts = parent?.value(LayoutContract.layoutBodies.token).flatMap(LayoutBody.init(propValue:))
        return (own ?? layouts)?.host
    }

    /// The hand holding the view itself, as `report` says: the view stays under it along its drag's axes, and goes
    /// back where its layout puts it let go - at the hand's speed - or taken away.
    func draggedLocally(_ report: HandReading.Report, in runtime: HostRuntime) {
        guard let drag = interactionProgram?.drag else { return }

        // A layout program places its views as its run wrote them: laid out right to left and mirrored, across
        // is the other way there.
        let turn = programPlacing?.layout.runDirection == .rightToLeft ? -1.0 : 1.0
        func along(_ move: Point) -> Point {
            Point(x: drag.axes == .vertical ? 0 : move.x * turn, y: drag.axes == .horizontal ? 0 : move.y)
        }
        var moved = local
        switch report.phase {
        case .began:
            dragFrom = report.at
            moved.held = .zero
        case .changed:
            moved.held = along(Point(x: report.at.x - dragFrom.x, y: report.at.y - dragFrom.y))
        case .ended:
            moved.held = nil
            moved.letGo = along(report.speed)
        case .cancelled:
            moved.held = nil
            moved.letGo = .zero
        }
        // A view a layout program places goes back by that layout's bodies; any other comes back here, as a
        // body of its own where it is one.
        if let held = local.held, moved.held == nil, programPlacing == nil, !runtime.reducesMotion() {
            let now = runtime.clock.now()
            localFollow.letGo(from: held, velocity: moved.letGo, on: bodyOfItsOwn, now: now)
            moved.pressed = localFollow.step(to: now)
            if localFollow.moves { runtime.handPace.opened(self) }
        }
        if moved != local {
            local = moved
            runtime.tree.movedLocally(self)
        }
        tellLayout(of: report, in: runtime)
    }

    /// Tells the layout placing the view of the hand that holds it, where the layout listens: the hand's phase,
    /// where it is in the layout's room, how fast it goes, how long it has stood still, and which of its views.
    /// Design: docs/design/host/interaction.md#a-layouts-view-in-the-hand
    private func tellLayout(of report: HandReading.Report, in runtime: HostRuntime) {
        guard let (layout, place) = programPlacing, layout.handler(.itemDragUpdated) != nil else { return }

        // The layout is told the hand as the view's drag takes it: along its axes alone, so what the layout makes
        // of it - what the view is over, a dismissal, a flight - goes the way the view went.
        let axes = interactionProgram?.drag?.axes ?? .both
        func along(_ move: Point) -> Point {
            Point(x: axes == .vertical ? 0 : move.x, y: axes == .horizontal ? 0 : move.y)
        }
        let moved = along(Point(x: report.at.x - dragFrom.x, y: report.at.y - dragFrom.y))
        let at = Point(x: dragFrom.x + moved.x, y: dragFrom.y + moved.y)
        // Where the view stood as the hand took it, which the hand's own place in the view is measured from -
        // from its other edge where the run is mirrored, as the arithmetic reads the room.
        if report.phase == .began { dragOrigin = layout.programPlace(at: place)?.bounds ?? .zero }
        let across = layout.runDirection == .rightToLeft ? dragOrigin.width - at.x : at.x
        layout.send(.itemDragUpdated, [
            .enumeration(report.phase.rawValue),
            .numbers([dragOrigin.x + across, dragOrigin.y + at.y]),
            .numbers(layout.alongRun(along(report.speed))),
            .number(report.still),
            .number(Double(place)),
        ], in: runtime)
    }

    /// The element no longer answers a press or is no longer taken by the hand: what either laid over it goes.
    func localInteractionChanged(in tree: MountedTree) {
        var kept = local
        if interactionProgram?.press == nil, interactionProgram?.drag == nil {
            localFollow.stop()
            kept.pressed = .identity
        }
        if interactionProgram?.drag == nil { kept.held = nil }
        guard kept != local else { return }

        local = kept
        tree.movedLocally(self)
    }

    private func present(pressed offset: PresentationOffset, in runtime: HostRuntime) {
        guard offset != local.pressed else { return }

        local.pressed = offset
        runtime.tree.movedLocally(self)
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A view the user throws away: let go far enough a way its drag's dismissal names, it flies on out of what shows
/// it, its handlers are told, and it comes back where nobody removed it.
/// Design: docs/design/host/interaction.md#a-view-thrown-away
extension MountedElement {
    /// Whether the element waits for what its dismissal's handlers do with it: it hears nothing meanwhile.
    var awaitsDismissal: Bool { awaitedDismissals > 0 }

    /// The way letting the view go dismisses it, the hand having taken it `gone` and lifting at `speed`, as the
    /// user sees both: the way its rule names that the view went furthest - where it stands, and what the rule's
    /// law carries a throw - past the threshold; nil where none is.
    static func dismissed(by rule: HostDismissal, gone: Point, speed: Point) -> SwipeDirection? {
        let ways: [(SwipeDirection, Double, Double)] = [
            (.up, -gone.y, -speed.y), (.down, gone.y, speed.y), (.left, -gone.x, -speed.x), (.right, gone.x, speed.x),
        ]
        let reached = ways.filter { rule.directions.contains(SwipeDirections(rawValue: $0.0.rawValue)) }
            .map { ($0.0, $0.1 + max(HostMotionLaw.carried($0.2, under: rule.motion), 0)) }
        return reached.filter { $0.1 > rule.threshold }.max { $0.1 < $1.1 }?.0
    }

    /// The view flies out `way` as the user sees it, from where the hand left it at `speed` - the drag's own
    /// numbers, mirrored with its layout's run - and its handlers are told the hand's `told` speed once it is out.
    func dismiss(_ way: SwipeDirection, from offset: Point, speed: Point, told: Point, in runtime: HostRuntime) {
        guard let rule = interactionProgram?.drag?.dismissal else { return }

        let mirrored = programPlacing?.layout.runDirection == .rightToLeft
        let flown: SwipeDirection = mirrored && way == .left ? .right : mirrored && way == .right ? .left : way
        // Where the view stands with no hand on it: a layout's view is shown where the hand left it, that far
        // from the place it is measured from.
        flownFrom = programPlacing.flatMap { layout, place in layout.programPlace(at: place)?.bounds }.map {
            Rect(x: $0.x - offset.x, y: $0.y - offset.y, width: $0.width, height: $0.height)
        } ?? laidOutFrame
        flight = PresentationOperation(
            .outside(flown), from: offset, speed: speed, pace: Double(rule.motion.milliseconds),
            room: dismissalSight?.room ?? LayoutSize(width: 0, height: 0), at: runtime.clock.now())
        dismissing = (way, told)
        runtime.handPace.opened(self)
    }

    /// A frame of the view's way out: it goes on, and once it has left the room its handlers are told.
    func flown(in runtime: HostRuntime) {
        guard var flying = flight else { return }

        let sight = dismissalSight
        let out = flying.step(to: runtime.clock.now(), frame: sight?.from, room: sight?.room)
        flight = out ? nil : flying
        if local.held != flying.offset {
            local.held = flying.offset
            runtime.tree.movedLocally(self)
        }
        if out { tellDismissed(in: runtime) } else { runtime.handPace.opened(self) }
    }

    /// A hand took the view on its way out: the flight ends where it stands, and nothing is told. How far the
    /// view stands from its place.
    func interruptFlight() -> Point? {
        guard let flying = flight else { return nil }

        flight = nil
        dismissing = nil
        return flying.offset
    }

    /// The room the view leaves, and where it flies from in it: what holds it - its layout for a view a program
    /// places, else its parent - as the toolkit laid it out, or what shows that where it draws beyond its own room;
    /// nil before the toolkit laid it out.
    private var dismissalSight: (from: Rect?, room: LayoutSize)? {
        guard let holder = programPlacing?.layout ?? parent, let laid = holder.laidOutRoom else { return nil }
        guard let sight = holder.standingInWhatShowsIt() else {
            return (flownFrom, LayoutSize(width: laid.width, height: laid.height))
        }
        let from = flownFrom.map {
            Rect(x: $0.x + sight.corner.x, y: $0.y + sight.corner.y, width: $0.width, height: $0.height)
        }
        return (from, sight.room)
    }

    private var laidOutFrame: Rect? {
        guard let corner = laidOutCorner, let size = laidOutRoom else { return nil }
        return Rect(x: corner.x, y: corner.y, width: size.width, height: size.height)
    }

    /// The view is out: its own handler and its layout's are told, and it waits for every run they start.
    /// Nobody told, it comes back at once.
    private func tellDismissed(in runtime: HostRuntime) {
        guard let dismissal = dismissing else { return }

        let payload: [HostValue] = [.enumeration(dismissal.way.rawValue), .numbers([dismissal.speed.x, dismissal.speed.y])]
        var told: [(Int32, [HostValue])] = []
        if let own = handler(.dismissed) { told.append((own, payload)) }
        if let (layout, place) = programPlacing, let layouts = layout.handler(.itemDismissed) {
            told.append((layouts, [.number(Double(place))] + payload))
        }
        dismissing = nil
        awaitedDismissals = told.count
        guard !told.isEmpty else { return comeBack(in: runtime) }

        // The runs may outlive the window: what they end into holds neither the element nor its runtime.
        for (handler, values) in told {
            runtime.dispatch(handler, payload: values) { [weak self, weak runtime] in
                guard let self, let runtime else { return }
                self.dismissalHandled(in: runtime)
            }
        }
    }

    /// One of the runs the dismissal started has ended: after the last, a view still standing comes back.
    private func dismissalHandled(in runtime: HostRuntime) {
        guard awaitedDismissals > 0 else { return }

        awaitedDismissals -= 1
        if awaitedDismissals == 0, lifecycle == .active { comeBack(in: runtime) }
    }

    /// The view nobody removed comes back to its place: by its layout's bodies, or as a body of its own.
    func comeBack(in runtime: HostRuntime) {
        guard let held = local.held else { return }

        local.held = nil
        local.letGo = .zero
        if programPlacing == nil, !runtime.reducesMotion() {
            let now = runtime.clock.now()
            localFollow.letGo(from: held, velocity: .zero, on: bodyOfItsOwn, now: now)
            local.pressed = localFollow.step(to: now)
        }
        runtime.tree.movedLocally(self)
        // Said out of any frame, as the handlers end: the next one shows the view where it stands again.
        runtime.handPace.opened(self)
    }
}

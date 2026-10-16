// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the user does to the element's view with a finger, a pen or the mouse, heard by the host layer's rule.
/// Design: docs/design/platforms/web/input.md
extension WebElement {
    /// Listens for what the element asks to hear, once for each kind; a kind it stops asking for is heard and let go.
    func listenForTheUser() {
        guard let view else { return }
        let hearing = element.hearing
        if hearing.contains(.taps), !listening.contains(.taps) {
            listening.insert(.taps)
            view.listen("click") { [weak self] in
                // A label's click comes again as its control's: one tap.
                guard let self, !press.wasDragged, !WebRelay.eventPassesToControl else { return }
                heard(.taps, .tap(run: WebRelay.eventClicks))
            }
            view.listen("activate") { [weak self] in self?.heard(.taps, .tap(run: 0)) }
        }
        if !hearing.isDisjoint(with: [.drags, .pinches]), listening.isDisjoint(with: [.drags, .pinches]) {
            listening.formUnion([.drags, .pinches])
            listenForPresses(view)
        }
        if hearing.contains(.hand), !listening.contains(.hand) {
            listening.insert(.hand)
            listenForTheHand(view)
        }
        if hearing.contains(.pointer), !listening.contains(.pointer) {
            listening.insert(.pointer)
            for (event, said) in Self.pointerEvents {
                view.listen(event) { [weak self] in self?.heard(.pointer, .pointer(said, WebRelay.eventPoint)) }
            }
        }
        if element.handler(.isFocusedChanged) != nil, !listensForFocus {
            listensForFocus = true
            view.listen("focus") { [weak self] in self?.send(.isFocusedChanged, [.bool(WebRelay.eventDetail != 0)]) }
        }
        view.isTapped = hearing.contains(.taps) && !view.isControl
        view.offerDrag(element.dragAndDrop) { [weak self] heard in
            guard let self, let host else { return }
            element.hear(heard, in: host.runtime)
        }
    }

    /// The DOM's pointer events, and what each says to the element.
    private static let pointerEvents: [(String, Event)] = [
        ("pointerenter", .pointerEntered), ("pointerleave", .pointerExited), ("pointermove", .pointerMoved),
        ("pointerdown", .pointerPressed), ("pointerup", .pointerReleased),
    ]

    /// A press dragged and a pinch: the view takes the pointers pressed on it from the page, which scrolls and zooms
    /// it no more, and hears them until they let go.
    /// Design: docs/design/platforms/web/input.md#a-press-dragged-and-a-pinch
    private func listenForPresses(_ view: WebDOMView) {
        view.style("touch-action", "none")
        view.style("user-select", "none")
        view.style("-webkit-user-select", "none")
        view.listen("pointerdown") { [weak self, weak view] in
            let pointer = WebRelay.eventPointer
            guard let self, let view, pointer.kind != 0 || pointer.button == 0 else { return }
            WebRelay.capturePointer(view.node)
            hearPress(press.down(
                pointer.id, at: pointer.at, kind: pointer.kind, origin: origin, size: WebRelay.eventSize))
        }
        view.listen("pointermove") { [weak self] in
            guard let self else { return }
            let pointer = WebRelay.eventPointer
            hearPress(press.moved(pointer.id, to: pointer.at, origin: origin, size: WebRelay.eventSize))
        }
        for (event, letGo) in [("pointerup", true), ("pointercancel", false)] {
            view.listen(event) { [weak self] in
                guard let self else { return }
                hearPress(press.up(WebRelay.eventPointer.id, letGo: letGo, origin: origin, size: WebRelay.eventSize))
            }
        }
        view.listen("wheel") { [weak self] in
            let wheel = WebRelay.eventWheel
            guard let self, wheel.pinches, element.hearing.contains(.pinches) else { return }
            WebRelay.takeEvent()
            hearPress(press.trackpad(
                scale: press.wheeled(down: wheel.down), at: WebRelay.eventPoint, size: WebRelay.eventSize))
            wheelStill()
        }
        for event in ["gesturestart", "gesturechange"] {
            view.listen(event) { [weak self] in
                guard let self, element.hearing.contains(.pinches) else { return }
                WebRelay.takeEvent()
                hearPress(press.trackpad(scale: WebRelay.eventScale, at: WebRelay.eventPoint, size: WebRelay.eventSize))
            }
        }
        view.listen("gestureend") { [weak self] in
            guard let self else { return }
            WebRelay.takeEvent()
            hearPress(press.trackpadEnded(at: WebRelay.eventPoint, size: WebRelay.eventSize))
        }
    }

    /// The hand over a layout: a pointer dragged - its first move past the drag distance along the layout's axis
    /// claims it, then held - and a wheel or a trackpad's scroll, a step the layout leaves going on to the page.
    /// Design: docs/design/platforms/web/input.md#the-hand-over-a-layout
    private func listenForTheHand(_ view: WebDOMView) {
        // The page keeps a touch across the layout's axis, its own scroll; along it the touch is the layout's.
        view.style("touch-action", element.handAxis == .vertical ? "pan-x" : "pan-y")
        view.style("user-select", "none")
        view.style("-webkit-user-select", "none")
        view.style("-webkit-touch-callout", "none")
        view.listen("pointerdown") { [weak self] in
            let pointer = WebRelay.eventPointer
            guard let self, pointer.kind != 0 || pointer.button == 0 else { return }
            handPointer = pointer.id
            handDown = pointer.at
            handLast = pointer.at
            handPending = true
            handTaking = false
            hand(.began, moved: Point(x: 0, y: 0), point: WebRelay.eventPoint)
        }
        view.listen("pointermove") { [weak self, weak view] in
            let pointer = WebRelay.eventPointer
            guard let self, let view, pointer.id == handPointer else { return }
            if handPending {
                let moved = Point(x: pointer.at.x - handDown.x, y: pointer.at.y - handDown.y)
                guard abs(moved.x) > Self.dragDistance || abs(moved.y) > Self.dragDistance else { return }
                handPending = false
                handTaking = hand(.changed, moved: moved)
                guard handTaking else {
                    handPointer = nil
                    return
                }
                WebRelay.capturePointer(view.node)
            } else if handTaking {
                hand(.changed, moved: Point(x: pointer.at.x - handLast.x, y: pointer.at.y - handLast.y))
            }
            handLast = pointer.at
            WebRelay.takeEvent()
        }
        // A touch the layout took is kept from the page's pan to its lift: the browser pans by the touch's moves, which
        // come after the pointer's, and would take a slant along the page's own axis.
        view.listen("touchmove") { [weak self] in
            if self?.handTaking == true { WebRelay.takeEvent() }
        }
        // And from the browser's own drag - of a picture under it, past a few points - which takes the pointer away
        // and never tells its lift.
        view.listen("dragstart") { [weak self] in
            guard let self else { return }
            if handTaking || element.holdsItem { WebRelay.takeEvent() }
        }
        for (event, letGo) in [("pointerup", true), ("pointercancel", false)] {
            view.listen(event) { [weak self] in
                guard let self, WebRelay.eventPointer.id == handPointer else { return }
                // Told whatever the hand moved: a press that held a view and never moved lets it go.
                hand(letGo ? .ended : .cancelled, moved: Point(x: 0, y: 0))
                handPointer = nil
                handPending = false
                handTaking = false
            }
        }
        // A wheel measured in lines or pages turns notch by notch; one in pixels - a trackpad's - is a stream.
        view.listen("wheel") { [weak self] in
            guard let self, !WebRelay.eventWheel.pinches, let host else { return }
            let step = WebRelay.eventScroll
            let heard = WebRelay.eventNotches.map { HeardInput.notch($0) } ?? .wheel(Point(x: -step.x, y: -step.y))
            if element.hear(heard, in: host.runtime) { WebRelay.takeEvent() }
        }
    }

    /// A wheel's notches over a layout, as many as it turned, across and down: the host's entry. Whether the layout
    /// took them.
    @discardableResult
    func notched(_ notches: Point) -> Bool {
        guard let host, element.hearing.contains(.hand) else { return false }
        return element.hear(.notch(notches), in: host.runtime)
    }

    /// The hand at `phase`, having moved what is under it by `moved` since the last, at `time` - the event's own,
    /// where one is heard: the host's entry. Whether the layout took it.
    @discardableResult
    func hand(
        _ phase: GesturePhase, moved: Point, speed: Point? = nil, at time: Double? = WebRelay.eventTime,
        point: Point? = nil
    ) -> Bool {
        guard let host, element.hearing.contains(.hand) else { return false }
        let told = time.flatMap { $0 > 0 ? $0 : nil }
        return element.hear(.hand(phase, moved: moved, speed: speed, at: told, point: point), in: host.runtime)
    }

    /// How far a pointer moves before it is a drag, in CSS pixels.
    private static let dragDistance = 4.0

    /// Where the view's top left corner stands on the page, by the event being heard.
    private var origin: Point {
        let (on, inView) = (WebRelay.eventPointer.at, WebRelay.eventPoint)
        return Point(x: on.x - inView.x, y: on.y - inView.y)
    }

    /// A wheel's pinch ends once the wheel stands still for a fifth of a second.
    private func wheelStill() {
        wheelTurns += 1
        let turn = wheelTurns
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, turn == wheelTurns else { return }
            hearPress(press.trackpadEnded(at: Point(x: 0, y: 0), size: LayoutSize(width: 0, height: 0)))
        }
    }

    private func hearPress(_ inputs: [HeardInput]) {
        for input in inputs {
            if case .pinch = input { heard(.pinches, input) } else { heard(.drags, input) }
        }
    }

    private func heard(_ kind: Hearing, _ input: HeardInput) {
        guard let host, element.hearing.contains(kind) else { return }
        element.hear(input, in: host.runtime)
    }
}

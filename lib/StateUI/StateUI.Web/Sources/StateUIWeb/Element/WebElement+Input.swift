// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import WASILibc

/// What the user does to the element's view with a finger, a pen or the mouse, heard by the host layer's rule.
/// Design: docs/design/platforms/web/input.md
extension WebElement {
    /// Listens for what the element asks to hear, once for each kind; a kind it stops asking for is heard and let go.
    func listenForTheUser() {
        guard let view else { return }
        let hearing = element.hearing
        if hearing.contains(.taps), !listening.contains(.taps) {
            listening.insert(.taps)
            view.followTapReach()
            view.listen("click") { [weak self, weak view] in
                // A label's click comes again as its control's: one tap.
                guard let self, view?.clickIsTap == true, !WebRelay.eventPassesToControl else { return }
                heard(.taps, .tap(run: WebRelay.eventClicks))
            }
            view.hear(.activate) { [weak self] in self?.heard(.taps, .tap(run: 0)) }
        }
        if hearing.contains(.holds) {
            view.holdTime = element.holdDuration ?? HandReading.hold
            if !listening.contains(.holds) {
                listening.insert(.holds)
                view.listenForHold { [weak self] in self?.held() }
            }
        }
        if !hearing.isDisjoint(with: Self.presses), listening.isDisjoint(with: Self.presses) {
            listening.formUnion(Self.presses)
            listenForPresses(view)
        }
        if hearing.contains(.hand), !listening.contains(.hand) {
            listening.insert(.hand)
            listenForTheHand(view)
        }
        if hearing.contains(.pointer), !listening.contains(.pointer) {
            listening.insert(.pointer)
            for (event, said) in Self.pointerEvents {
                view.listen(event) { [weak self] in
                    let byFinger = WebRelay.eventPointer.kind == .touch
                    self?.heard(.pointer, .pointer(said, WebRelay.eventPoint, byFinger: byFinger))
                }
            }
        }
        if element.handler(.isFocusedChanged) != nil, !listensForFocus {
            listensForFocus = true
            view.hear(.within) { [weak self] in self?.send(.isFocusedChanged, [.bool(WebRelay.eventDetail != 0)]) }
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
            guard let self, let view, pointer.kind != .mouse || pointer.button == 0 else { return }
            WebRelay.capturePointer(view.node)
            // A press with ⌥/Alt over a view two fingers move is two fingers, mirrored about its middle.
            if WebRelay.eventAlt, element.hearsMirroredFingers, mirroring == nil {
                mirroring = pointer.id
                WebRelay.takeEvent()
                return hearMirrored(.began)
            }
            hearPress(press.down(
                pointer.id, at: pointer.at, kind: pointer.kind, origin: origin, size: WebRelay.eventSize))
        }
        view.listen("pointermove") { [weak self] in
            guard let self else { return }
            let pointer = WebRelay.eventPointer
            if mirroring == pointer.id {
                WebRelay.takeEvent()
                return hearMirrored(.changed)
            }
            hearPress(press.moved(pointer.id, to: pointer.at, origin: origin, size: WebRelay.eventSize))
        }
        for (event, letGo) in [("pointerup", true), ("pointercancel", false)] {
            view.listen(event) { [weak self] in
                guard let self else { return }
                if mirroring == WebRelay.eventPointer.id {
                    mirroring = nil
                    return hearMirrored(letGo ? .ended : .cancelled)
                }
                hearPress(press.up(WebRelay.eventPointer.id, letGo: letGo, origin: origin, size: WebRelay.eventSize))
            }
        }
        view.listen("wheel") { [weak self] in
            let wheel = WebRelay.eventWheel
            guard let self, wheel.pinches, element.hearing.contains(.pinches) else { return }
            WebRelay.takeEvent()
            // The browser tells a trackpad's pinch as a wheel turned with Control, its turn a hundredth of the
            // scale's logarithm, in pixels; the host layer lets it go once the wheel stands still.
            let size = WebRelay.eventSize
            let at = PinchStep.share(of: WebRelay.eventPoint, width: size.width, height: size.height)
            heard(.pinches, .wheelPinch(scale: exp(-wheel.down / 100), at: at))
        }
        for event in ["gesturestart", "gesturechange"] {
            view.listen(event) { [weak self] in
                guard let self, !element.hearing.isDisjoint(with: [.pinches, .rotations]) else { return }
                WebRelay.takeEvent()
                hearPress(press.trackpad(
                    scale: WebRelay.eventScale, degrees: WebRelay.eventRotation, at: WebRelay.eventPoint,
                    size: WebRelay.eventSize))
            }
        }
        view.listen("gestureend") { [weak self] in
            guard let self else { return }
            WebRelay.takeEvent()
            hearPress(press.trackpadEnded(at: WebRelay.eventPoint, size: WebRelay.eventSize))
        }
    }

    /// The hand over a layout: the pointers down, read as one at their middle - its first move past the drag
    /// distance the layout's way claims it, then held - and a wheel or a trackpad's scroll, a step the layout leaves
    /// going on to the page.
    /// Design: docs/design/platforms/web/input.md#the-hand-over-a-layout
    private func listenForTheHand(_ view: WebDOMView) {
        // The page keeps a touch across the layout's axis, its own scroll; along it the touch is the layout's - and a
        // pan's every way.
        let way = element.handWay
        view.style("touch-action", way == .everyWay ? "none" : way == .vertical ? "pan-x" : "pan-y")
        view.style("user-select", "none")
        view.style("-webkit-user-select", "none")
        view.style("-webkit-touch-callout", "none")
        view.listen("pointerdown") { [weak self, weak view] in
            let pointer = WebRelay.eventPointer
            guard let self, let view, pointer.kind != .mouse || pointer.button == 0 else { return }
            // A press with ⌥/Alt over a layout two fingers move is theirs.
            guard !(WebRelay.eventAlt && element.hearsMirroredFingers) else { return }
            // The hand's fingers, as the host layer reads them; another finger joins a hand under way.
            guard case .began(let at) = handRecognition.down(pointer.id, at: pointer.at, inView: WebRelay.eventPoint)
            else {
                if handRecognition.isTaken { WebRelay.capturePointer(view.node) }
                return
            }
            hand(.began, moved: Point(x: 0, y: 0), point: at)
        }
        view.listen("pointermove") { [weak self, weak view] in
            let pointer = WebRelay.eventPointer
            guard let self, let view, handRecognition.isOpen else { return }
            switch handRecognition.moved(pointer.id, to: pointer.at) {
            case .asks(let travel):
                handRecognition.answered(taken: hand(.changed, moved: travel))
                if handRecognition.isTaken { WebRelay.capturePointer(view.node) }
            case .moved(let step):
                hand(.changed, moved: step)
            default:
                break
            }
            if handRecognition.isTaken { WebRelay.takeEvent() }
        }
        // A touch the layout took is kept from the page's pan to its lift: the browser pans by the touch's moves, which
        // come after the pointer's, and would take a slant along the page's own axis.
        view.listen("touchmove") { [weak self] in
            if self?.handRecognition.isTaken == true { WebRelay.takeEvent() }
        }
        // And from the browser's own drag - of a picture under it, past a few points - which takes the pointer away
        // and never tells its lift: kept from a hand the layout took, and from one it may still take - Chromium's own
        // threshold comes before the hand's drag distance, by no rule.
        view.listen("dragstart") { [weak self] in
            guard let self else { return }
            if handRecognition.isOpen || element.holdsItem { WebRelay.takeEvent() }
        }
        for (event, letGo) in [("pointerup", true), ("pointercancel", false)] {
            view.listen(event) { [weak self] in
                // The last finger lifting ends the hand, told whatever it moved: a press that held a view and never
                // moved lets it go.
                guard let self, case .ended = handRecognition.up(WebRelay.eventPointer.id, letGo: letGo) else { return }
                hand(letGo ? .ended : .cancelled, moved: Point(x: 0, y: 0))
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

    /// Where the view's top left corner stands on the page, by the event being heard.
    private var origin: Point {
        let (on, inView) = (WebRelay.eventPointer.at, WebRelay.eventPoint)
        return Point(x: on.x - inView.x, y: on.y - inView.y)
    }

    private func hearPress(_ inputs: [HeardInput]) {
        for input in inputs {
            switch input {
            case .pinch: heard(.pinches, input)
            case .rotation: heard(.rotations, input)
            default: heard(.drags, input)
            }
        }
    }

    /// What the presses on a view are heard for: a drag, two fingers pinching, two fingers turning.
    private static let presses: Hearing = [.drags, .pinches, .rotations]

    /// The press with ⌥/Alt at `phase`, where the event being heard stands, mirrored about the view's middle.
    /// Design: docs/design/host/runtime.md#two-fingers-from-one-pointer
    private func hearMirrored(_ phase: GesturePhase) {
        guard let host else { return }
        let size = WebRelay.eventSize
        element.hear(
            .mirrored(phase, at: WebRelay.eventPoint, middle: Point(x: size.width / 2, y: size.height / 2)),
            in: host.runtime)
    }

    /// The relay held a press: the hold's where it has not become a drag, by the host layer's rule.
    private func held() {
        guard press.held() else { return }
        heard(.holds, .hold)
    }

    private func heard(_ kind: Hearing, _ input: HeardInput) {
        guard let host, element.hearing.contains(kind) else { return }
        element.hear(input, in: host.runtime)
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// What the user does: clicks, reported values, gestures, scrolling and frame reports.
extension AppKitElement {
    @objc func clicked(_ sender: Any?) {
        guard let handler = events[.clicked] else { return }
        host?.dispatch(handler)
    }

    /// A value the user of a registered view changed, by member.
    func report(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host else { return }

        // A RADIO BUTTON'S SET LIVES ACROSS THE WINDOW, where AppKit clears only
        // the buttons of one superview: the button reports that it is on, and
        // the host - which holds the tree - takes the check off the others in
        // the same breath.
        guard type == .radioButton, property == .isOn, value.bool == true else {
            return carry(property, event, value)
        }

        host.performUserTransaction {
            clearRadioPeers()
            carry(property, event, value)
        }
    }

    /// The other buttons of this one's set lose their check, each reporting
    /// what it became.
    func clearRadioPeers() {
        for peer in element.radioPeers.map(\.appKit) where peer.bool(.isOn) == true {
            peer.setRadioChecked(false)
            peer.carry(.isOn, .toggled, .bool(false))
        }
    }

    /// One reported value: onto the state the element carries it in - text
    /// where the value is text, lanes where it is a number, a flag or a choice
    /// - and to the element's handler for the event.
    func carry(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host else { return }

        let carried: HostStateValue? = switch value {
        case .string(let text): .text(text)
        case .name(let name): .text(name)
        case .bool(let flag): .lanes([flag ? 1 : 0])
        case .number(let number): .lanes([number])
        case .numbers(let numbers): .lanes(numbers)
        case .enumeration(let choice): .lanes([Double(choice)])
        default: nil
        }

        var reported = false

        if let carried, let binding = driven[property] {
            // A JOURNEY THE HOST CARRIES is taken at the position the user has
            // just established - the old destination and velocity stop pulling
            // against the hand. A value the host merely sets is reported as it
            // stands.
            if case .lanes(let lanes) = carried, binding.kind == .property {
                reported = host.take(lanes, through: binding)
            } else {
                reported = host.report(carried, through: binding)
            }
        }

        if let handler = events[event] {
            host.dispatch(handler, payload: [value])
        } else if reported {
            host.settleUserWrite(true)
        }
    }

    func tapped() {
        guard let handler = events[.tapped] else { return }
        host?.dispatch(handler)
    }

    func swiped(_ direction: Int32) {
        guard let handler = events[.swiped] else { return }
        host?.dispatch(handler, payload: [.enumeration(direction)])
    }

    func panChanged(_ phase: AppKitGesturePhase, total: NSPoint) {
        guard let host else { return }
        let across = whole(.panXChannel).flatMap { $0 == 0 ? nil : Int32($0) }
        let down = whole(.panYChannel).flatMap { $0 == 0 ? nil : Int32($0) }

        if phase == .started {
            panFromX = across.flatMap(host.standingGestureValue(state:)) ?? 0
            panFromY = down.flatMap(host.standingGestureValue(state:)) ?? 0
        }

        var changedState = false
        host.performUserTransaction {
            if phase == .running {
                if let across {
                    changedState = host.takeGestureValue(
                        panFromX + Double(total.x), state: across) || changedState
                }
                if let down {
                    changedState = host.takeGestureValue(
                        panFromY + Double(total.y), state: down) || changedState
                }
            }

            if let handler = events[.panUpdated] {
                host.dispatch(handler, payload: [
                    .enumeration(phase.rawValue),
                    .number(Double(total.x)),
                    .number(Double(total.y)),
                ])
            }
        }
        host.settleUserWrite(changedState)
    }

    func pinchChanged(
        _ phase: AppKitGesturePhase,
        scale: CGFloat,
        origin: NSPoint
    ) {
        guard let handler = events[.pinchUpdated] else { return }
        host?.dispatch(handler, payload: [
            .enumeration(phase.rawValue),
            .number(Double(scale)),
            .numbers([Double(origin.x), Double(origin.y)]),
        ])
    }

    func pointerChanged(
        _ report: AppKitPointerRecognizer.Report,
        point: NSPoint?
    ) {
        let event: Event = switch report {
        case .entered: .pointerEntered
        case .exited: .pointerExited
        case .moved: .pointerMoved
        case .pressed: .pointerPressed
        case .released: .pointerReleased
        }
        guard let handler = events[event] else { return }
        let payload: [HostValue] = point.map {
            [.numbers([Double($0.x), Double($0.y)])]
        } ?? []
        host?.dispatch(handler, payload: payload)
    }

    func scrolled(from old: NSPoint, to new: NSPoint) {
        guard let host else { return }
        var tookState = false
        host.performUserTransaction {
            if old != new, let binding = driven[.scrollOffset] {
                tookState = host.take([Double(new.x), Double(new.y)], through: binding)
            }

            if old.x != new.x, let handler = events[.scrollXChanged] {
                host.dispatch(handler, payload: [.number(Double(new.x))])
            }
            if old.y != new.y, let handler = events[.scrollYChanged] {
                host.dispatch(handler, payload: [.number(Double(new.y))])
            }
        }
        host.settleUserWrite(tookState)
    }

    func scrollStopped() {
        guard let handler = events[.scrollStopped] else { return }
        host?.dispatch(handler)
    }

    /// Hands an event a registered view raised to this element's handler for
    /// it - nothing where the tree subscribed none.
    func send(_ event: Event, _ values: [HostValue]) {
        guard let handler = events[event] else { return }

        host?.dispatch(handler, payload: values)
    }

    func setRadioChecked(_ checked: Bool) {
        (view as? AppKitRadioButtonView)?.setCheckedFromGroup(checked)
    }

    func configureFrameObservation() {
        guard view != nil else { return }
        let wanted = driven[.frame] != nil || events[.frameChanged] != nil

        if !wanted {
            if observesFrame {
                NotificationCenter.default.removeObserver(
                    self, name: NSView.frameDidChangeNotification, object: nil)
                NotificationCenter.default.removeObserver(
                    self, name: NSView.boundsDidChangeNotification, object: nil)
                frameObservedViews.removeAll(keepingCapacity: true)
                observesFrame = false
            }
            return
        }

        if !observesFrame {
            observesFrame = true
        }

        refreshFrameObservationChain()
        queueFrameReport()
    }

    /// A stationary child's window-space origin changes when an ancestor moves
    /// or a clip view scrolls. Observe the current native chain and rebuild it
    /// after reparenting instead of treating the child's frame as sufficient.
    func refreshFrameObservationChain() {
        guard observesFrame, let view else { return }
        var chain: [NSView] = []
        var current: NSView? = view

        while let candidate = current {
            chain.append(candidate)
            if candidate === view.window?.contentView { break }
            current = candidate.superview
        }

        let unchanged = chain.count == frameObservedViews.count
            && zip(chain, frameObservedViews).allSatisfy { $0 === $1 }
        guard !unchanged else { return }

        NotificationCenter.default.removeObserver(
            self, name: NSView.frameDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: NSView.boundsDidChangeNotification, object: nil)
        frameObservedViews = chain

        for observed in chain {
            observed.postsFrameChangedNotifications = true
            observed.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(frameDidChange(_:)),
                name: NSView.frameDidChangeNotification,
                object: observed)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(frameDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: observed)
        }
    }

    func configureGestures() {
        guard let view else { return }

        if events[.tapped] != nil {
            let recognizer: AppKitTapRecognizer

            if let existing = tapRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitTapRecognizer { [weak self] in self?.tapped() }
                tapRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }

            recognizer.apply(tapCount: whole(.tapCount) ?? 1)
        } else if let recognizer = tapRecognizer {
            view.removeGestureRecognizer(recognizer)
            tapRecognizer = nil
        }

        (view as? AppKitHitTestView)?.pressAction = events[.tapped] == nil
            ? nil
            : { [weak self] in self?.tapped() }

        if events[.swiped] != nil {
            let recognizer: AppKitSwipeRecognizer
            if let existing = swipeRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitSwipeRecognizer { [weak self] direction in
                    self?.swiped(direction)
                }
                swipeRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }
            recognizer.directions = enumeration(.swipeDirection) ?? 15
            recognizer.threshold = max(
                0,
                number(.swipeThreshold).map { CGFloat($0) } ?? 40)
        } else if let recognizer = swipeRecognizer {
            view.removeGestureRecognizer(recognizer)
            swipeRecognizer = nil
        }

        let panX = whole(.panXChannel).flatMap { $0 == 0 ? nil : Int32($0) }
        let panY = whole(.panYChannel).flatMap { $0 == 0 ? nil : Int32($0) }
        let wantsPan = events[.panUpdated] != nil || panX != nil || panY != nil
        if wantsPan {
            let recognizer: AppKitPanRecognizer
            if let existing = panRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitPanRecognizer { [weak self] phase, total in
                    self?.panChanged(phase, total: total)
                }
                panRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }

            // AppKit's stable pan contract is a primary-pointer drag. The
            // multi-touch count API before macOS 26 refers to Touch Bar input,
            // so an authored count other than one cannot truthfully match here.
            recognizer.isEnabled = whole(.panTouchCount).map { $0 == 1 } ?? true
        } else if let recognizer = panRecognizer {
            view.removeGestureRecognizer(recognizer)
            panRecognizer = nil
        }

        if events[.pinchUpdated] != nil {
            if pinchRecognizer == nil {
                let recognizer = AppKitPinchRecognizer { [weak self] phase, scale, origin in
                    self?.pinchChanged(phase, scale: scale, origin: origin)
                }
                pinchRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }
        } else if let recognizer = pinchRecognizer {
            view.removeGestureRecognizer(recognizer)
            pinchRecognizer = nil
        }

        let pointerEvents = [
            Event.pointerEntered, .pointerExited, .pointerMoved, .pointerPressed, .pointerReleased,
        ]
        if pointerEvents.contains(where: { events[$0] != nil }) {
            let recognizer: AppKitPointerRecognizer
            if let existing = pointerRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitPointerRecognizer { [weak self] report, point in
                    self?.pointerChanged(report, point: point)
                }
                pointerRecognizer = recognizer
            }
            recognizer.install(on: view)
        } else if let recognizer = pointerRecognizer {
            recognizer.detach()
            pointerRecognizer = nil
        }
    }

    @objc func frameDidChange(_ notification: Notification) {
        queueFrameReport()
    }

    func queueFrameReport() {
        guard !frameQueued else { return }
        frameQueued = true

        DispatchQueue.main.async { [weak self] in
            self?.flushFrameReport()
        }
    }

    func flushFrameReport() {
        frameQueued = false
        refreshFrameObservationChain()
        guard let view, let content = view.window?.contentView else { return }

        let parentFrame = topLeftFrame(view.frame, in: view.superview)
        let windowFrame = topLeftFrame(view.convert(view.bounds, to: content), in: content)
        let safeArea = topLeftFrame(content.safeAreaRect, in: content)
        let report = [
            parentFrame.minX, parentFrame.minY, parentFrame.width, parentFrame.height,
            windowFrame.minX, windowFrame.minY,
            windowFrame.minX - safeArea.minX, windowFrame.minY - safeArea.minY,
        ].map(Double.init)

        guard report != lastFrameReport else { return }
        lastFrameReport = report

        let reported = driven[.frame].map {
            host?.report(.lanes(Array(report.prefix(4))), through: $0) ?? false
        } ?? false

        if let handler = events[.frameChanged] {
            host?.dispatch(handler, payload: [.numbers(report)])
        } else if reported {
            host?.pump()
        }
    }

    func flushFrameReportForTesting() {
        flushFrameReport()
    }

    var frameReportQueuedForTesting: Bool { frameQueued }

    func topLeftFrame(_ frame: NSRect, in parent: NSView?) -> NSRect {
        guard let parent, !parent.isFlipped else { return frame }
        return NSRect(
            x: frame.minX,
            y: parent.bounds.height - frame.maxY,
            width: frame.width,
            height: frame.height)
    }
}
#endif

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the user does: clicks, reported values, gestures, scrolling and frame reports.
extension AppKitElement {
    @objc func clicked(_ sender: Any?) {
        send(.clicked, [])
    }

    /// A value the user changed in the view; a radio button's peers turned off on their own buttons.
    func report(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host else { return }
        element.reportUserChange(property, event, value, in: host.runtime) { peer in
            (peer.native as? AppKitElement)?.setRadioChecked(false)
        }
    }

    func tapped() {
        send(.tapped, [])
    }

    func swiped(_ direction: Int32) {
        send(.swiped, [.enumeration(direction)])
    }

    func panChanged(_ phase: AppKitGesturePhase, total: NSPoint) {
        guard let host else { return }
        let across = whole(.panXChannel).flatMap { $0 == 0 ? nil : Int32($0) }
        let down = whole(.panYChannel).flatMap { $0 == 0 ? nil : Int32($0) }

        if phase == .started {
            panFromX = across.flatMap(host.runtime.standingGestureValue(state:)) ?? 0
            panFromY = down.flatMap(host.runtime.standingGestureValue(state:)) ?? 0
        }

        let runtime = host.runtime
        runtime.performUserTransaction {
            if phase == .running {
                if let across { runtime.takeGestureValue(panFromX + Double(total.x), state: across) }
                if let down { runtime.takeGestureValue(panFromY + Double(total.y), state: down) }
            }
            send(.panUpdated, [.enumeration(phase.rawValue), .number(Double(total.x)), .number(Double(total.y))])
        }
    }

    func pinchChanged(
        _ phase: AppKitGesturePhase,
        scale: CGFloat,
        origin: NSPoint
    ) {
        send(.pinchUpdated, [
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
        send(event, point.map { [.numbers([Double($0.x), Double($0.y)])] } ?? [])
    }

    /// The user moved the scroller from `old` to `new`, as the display's frame saw it.
    func scrolled(from old: NSPoint, to new: NSPoint) {
        guard let host else { return }
        element.reportScrolled(
            from: Point(x: Double(old.x), y: Double(old.y)), to: Point(x: Double(new.x), y: Double(new.y)),
            in: host.runtime)
    }

    func scrollStopped() {
        send(.scrollStopped, [])
    }

    /// An event the view raised, with what it carries.
    func send(_ event: Event, _ values: [HostValue]) {
        guard let host else { return }
        element.send(event, values, in: host.runtime)
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
        guard let numbers = frameNumbers(), let host else { return }

        // One of the user's transactions, so a turn renders what the report moved.
        host.runtime.performUserTransaction { element.reportFrame(numbers, in: host.runtime) }
    }

    /// Where the view stands now, as a frame report says it: in its parent, in its window, and from the window's
    /// content clear of its chrome - each from the top left; nil for a view in no window.
    func frameNumbers() -> [Double]? {
        guard let view, let content = view.window?.contentView else { return nil }

        let parentFrame = topLeftFrame(view.frame, in: view.superview)
        let windowFrame = topLeftFrame(view.convert(view.bounds, to: content), in: content)
        let safeArea = topLeftFrame(content.safeAreaRect, in: content)
        return MountedElement.frameNumbers(
            place: parentFrame.placed,
            corner: Point(x: Double(windowFrame.minX), y: Double(windowFrame.minY)),
            content: Point(x: Double(safeArea.minX), y: Double(safeArea.minY)))
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

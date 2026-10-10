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

    /// What a recognizer heard, turned into the element's events by the host layer's rule.
    func hear(_ heard: HeardInput) {
        guard let host else { return }
        element.hear(heard, in: host.runtime)
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

    /// Follows where the view stands while the tree reads it (`MountedElement.readsOwnFrame`): the host layer asks
    /// the view on the display's frames after anything moved, and the view's ancestors are watched for moving.
    /// Design: docs/design/platforms/appkit/input.md#where-a-view-stands
    func configureFrameObservation() {
        guard view != nil, let host else { return }
        let reads = element.readsOwnFrame
        host.runtime.frames.follow(self, order: Int64(truncatingIfNeeded: mount), reads: reads)

        if !reads {
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

        observesFrame = true
        refreshFrameObservationChain()
        host.runtime.frames.laidOut()
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

    /// Installs the recognizers for what the element asks to hear (`MountedElement.hearing`) and for a drag of it
    /// between views (`MountedElement.dragAndDrop`), and takes away those it no longer does.
    /// Design: docs/design/platforms/appkit/input.md#what-the-user-does
    func configureGestures() {
        guard let view else { return }
        let hearing = element.hearing
        let heard: AppKitHearing = { [weak self] input in self?.hear(input) }

        tapRecognizer = installed(tapRecognizer, hearing.contains(.taps), on: view) { AppKitTapRecognizer(hearing: heard) }
        (view as? AppKitHitTestView)?.pressAction = hearing.contains(.taps)
            ? { [weak self] in self?.hear(.tap(run: 0)) }
            : nil
        panRecognizer = installed(panRecognizer, hearing.contains(.drags), on: view) { AppKitPanRecognizer(hearing: heard) }
        pinchRecognizer = installed(pinchRecognizer, hearing.contains(.pinches), on: view) {
            AppKitPinchRecognizer(hearing: heard)
        }

        let offered = element.dragAndDrop
        dragSource = installed(dragSource, offered.words != nil, on: view) { AppKitDragSource(hearing: heard) }
        dragSource?.words = offered.words ?? ""

        if hearing.contains(.pointer) {
            let recognizer = pointerRecognizer ?? AppKitPointerRecognizer(hearing: heard)
            pointerRecognizer = recognizer
            recognizer.install(on: view)
        } else if let recognizer = pointerRecognizer {
            recognizer.detach()
            pointerRecognizer = nil
        }
    }

    /// `standing`, kept where `wanted` - made by `make` where there is none - on `view`; nil, taken off, where not.
    private func installed<Recognizer: NSGestureRecognizer>(
        _ standing: Recognizer?, _ wanted: Bool, on view: NSView, make: () -> Recognizer
    ) -> Recognizer? {
        guard wanted else {
            if let standing { view.removeGestureRecognizer(standing) }
            return nil
        }
        if let standing { return standing }
        let made = make()
        view.addGestureRecognizer(made)
        return made
    }

    /// The view or one of its ancestors moved: whoever reads a frame says it on the display's next frame.
    @objc func frameDidChange(_ notification: Notification) {
        refreshFrameObservationChain()
        host?.runtime.frames.laidOut()
    }

    /// Where the view stands now, as a frame report says it: in its parent, in its window, and from the window's
    /// content clear of its chrome - each from the top left; nil for a view in no window, or one no layout placed yet:
    /// StateUI's, or AppKit's giving it a size.
    /// Design: docs/design/platforms/appkit/input.md#where-a-view-stands
    func frameNumbers() -> [Double]? {
        guard let view, let content = view.window?.contentView,
              MountedElement.isLaidOut(placed: isPlaced, width: view.frame.width, height: view.frame.height)
        else { return nil }

        let parentFrame = topLeftFrame(view.frame, in: view.superview)
        let windowFrame = topLeftFrame(view.convert(view.bounds, to: content), in: content)
        let safeArea = topLeftFrame(content.safeAreaRect, in: content)
        return MountedElement.frameNumbers(
            place: parentFrame.placed,
            corner: Point(x: Double(windowFrame.minX), y: Double(windowFrame.minY)),
            content: Point(x: Double(safeArea.minX), y: Double(safeArea.minY)))
    }


    func topLeftFrame(_ frame: NSRect, in parent: NSView?) -> NSRect {
        guard let parent, !parent.isFlipped else { return frame }
        return NSRect(
            x: frame.minX,
            y: parent.bounds.height - frame.maxY,
            width: frame.width,
            height: frame.height)
    }
}

extension AppKitElement: FrameReporter {
    /// Says where the element stands, where that changed (`MountedElement.reportFrame`).
    func reportFrame() {
        guard let host, let numbers = frameNumbers() else { return }
        element.reportFrame(numbers, in: host.runtime)
    }
}

/// A menu that enables its items by asking - the menu bar's - asks the element an item tells when chosen.
extension AppKitElement: NSMenuItemValidation {
    /// Whether the item can be chosen: as the tree says.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        element.value(.isEnabled)?.bool ?? true
    }
}
#endif

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The Web half of a mounted element: its DOM element and everything hung on it.
/// Design: docs/design/host/tree.md#the-native-half
@MainActor
final class WebElement: NativeElement {
    /// The element of the mounted tree this is the Web half of; it owns this half.
    unowned let element: MountedElement

    /// The element's view; nil for an element with none of its own.
    private(set) var view: WebDOMView?

    weak var host: WebRenderer?

    /// The kinds of the user's input the view listens for already.
    var listening: Hearing = []

    /// Whether the view's size changing is followed, for a frame the tree reads.
    var observesSize = false

    /// Whether the view listens for the user's asking for its context menu.
    var listensForMenu = false

    /// The pointers pressed on the view, for a drag or a pinch it hears, and how many times a wheel turned a pinch.
    var press = WebPress()
    var wheelTurns = 0

    init(_ element: MountedElement, host: WebRenderer) {
        self.element = element
        self.host = host
        view = makeView()
    }

    var type: NodeType { element.type }
    var parent: WebElement? { element.parent?.web }

    var presentsView: Bool { view != nil }

    /// A slider's or a stepper's value as it stands on the page, where an animation of it starts.
    func standingValue(_ property: Prop) -> HostValue? {
        guard property == .value else { return nil }
        if let slider = view as? WebSliderView { return .number(slider.value) }
        return (view as? WebStepperView).map { .number($0.value) }
    }

    func animates(_ property: Prop) -> Bool {
        WebTransitionSurface.presents(property, on: type)
    }

    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        host?.placements.beforeChange()
        if wasDescribed, changed.contains(.isVisible) { crossVisibility() }
        applyProperties(changed: changed)
        followPages(changed: changed, wasDescribed: wasDescribed)
        configureLayoutMotion()
        arrangeChildren()
        listenForTheUser()
        offerContextMenu()
        followFrame()
    }

    func presentFrame(_ changed: Set<Prop>) {
        applyProperties(changed: changed)
    }

    func directionChanged() {
        view?.setDirection(element.layoutDirection)
    }

    func leave() {
        host?.placements.beforeChange()
        if let view { host?.runtime.frames.follow(self, order: view.serial, reads: false) }
        view?.detach()
    }

    /// An event the view raised, with what it carries.
    func send(_ event: Event, _ values: [HostValue]) {
        guard let host else { return }
        element.send(event, values, in: host.runtime)
    }

    /// A value the user changed in the view; a radio button's peers turned off on their own buttons.
    func report(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host else { return }
        element.reportUserChange(property, event, value, in: host.runtime) { peer in
            ((peer.native as? WebElement)?.view as? WebRadioView)?.setOn(false)
        }
    }
}

extension MountedElement {
    /// This element's Web half.
    var web: WebElement { native as! WebElement }
}

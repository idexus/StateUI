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
    var listensForButtonMenu = false

    /// Whether the view listens for the keyboard coming into it and leaving it.
    var listensForFocus = false

    /// The pointers pressed on the view, for a drag or a pinch it hears.
    var press = WebPress()

    /// The pointer pressed with ⌥/Alt over the element, read as two fingers, while it is down.
    var mirroring: Int?

    /// The hand over a layout, its fingers as the host layer reads them: past four CSS pixels along either axis it
    /// asks the layout.
    var handRecognition = HandRecognition(distance: .eachAxis(x: 4, y: 4))

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
        // Nothing of its own changed and no child moved - a change inside a child, which the child applies: nothing
        // of the element's own is placed, read or written again.
        // Design: docs/design/platforms/web/layout.md#a-change-inside-a-child
        let still = wasDescribed && changed.isEmpty && !element.childrenNeedArranging
        if !still {
            host?.placements.beforeChange(along: layoutsUp)
            if wasDescribed, changed.contains(.isVisible) { crossVisibility() }
            applyProperties(changed: changed)
            if let view, let host {
                element.applyDrawnChildren(to: view, through: WebRegistrations.registry, in: host.runtime)
            }
            followPages(changed: changed, wasDescribed: wasDescribed)
        }
        configureLayoutMotion()
        if !still { arrangeChildren() }
        // A page stands against its safe area again as it or its content says another way (`standInTheSafeArea`).
        if !still { standInTheSafeArea() }
        if changed.contains(.avoidsSafeArea) { element.parent?.web.standInTheSafeArea() }
        listenForTheUser()
        offerContextMenu()
        offerButtonMenu()
        configurePopover()
        followFrame()
    }

    func presentFrame(_ changed: Set<Prop>) {
        applyProperties(changed: changed)
        if changed.contains(.isPresented) { configurePopover() }
        if !changed.isDisjoint(with: MountedElement.sidebarMaterials), let split = view as? WebSplitView {
            split.ground(beside: element.sidebarMaterial(over: false), over: element.sidebarMaterial(over: true))
            host?.refreshChrome()
        }
    }

    func directionChanged() {
        view?.setDirection(element.layoutDirection)
    }

    func leave() {
        host?.placements.beforeChange(along: layoutsUp)
        view?.release()
    }

    /// An event the view raised, with what it carries.
    func send(_ event: Event, _ values: [HostValue]) {
        guard let host else { return }
        element.send(event, values, in: host.runtime)
    }

    /// A menu's entry or a bar's item chosen (`MountedElement.chosen`).
    func choose() {
        guard let host else { return }
        element.chosen(in: host.runtime)
    }

    /// A value the user changed in the view, by the host layer's rule (`reportUserChange`).
    func report(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host else { return }
        element.reportUserChange(property, event, value, in: host.runtime)
    }
}

extension MountedElement {
    /// This element's Web half.
    var web: WebElement { native as! WebElement }
}

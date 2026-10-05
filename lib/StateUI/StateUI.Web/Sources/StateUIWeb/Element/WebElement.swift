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

    init(_ element: MountedElement, host: WebRenderer) {
        self.element = element
        self.host = host
        view = makeView()
    }

    var type: NodeType { element.type }
    var parent: WebElement? { element.parent?.web }

    var presentsView: Bool { view != nil }

    func standingValue(_ property: Prop) -> HostValue? { nil }

    /// The browser animates nothing of StateUI's yet: every change arrives at once.
    func animates(_ property: Prop) -> Bool { false }

    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        applyProperties(changed: changed)
        arrangeChildren()
    }

    func presentFrame(_ changed: Set<Prop>) {
        applyProperties(changed: changed)
    }

    func directionChanged() {
        view?.setDirection(element.layoutDirection)
    }

    func leave() {
        view?.detach()
    }

    /// An event the view raised, with what it carries.
    func send(_ event: Event, _ values: [HostValue]) {
        guard let host else { return }
        element.send(event, values, in: host.runtime)
    }

    /// A value the user changed in the view.
    func report(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host else { return }
        element.reportUserChange(property, event, value, in: host.runtime) { _ in }
    }
}

extension MountedElement {
    /// This element's Web half.
    var web: WebElement { native as! WebElement }
}

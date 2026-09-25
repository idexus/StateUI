// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The GTK half of a mounted element: its widget and everything hung on it.
/// Design: docs/design/host/tree.md#the-native-half
@MainActor
final class GTKElement: NativeElement {
    /// The element of the mounted tree this is the GTK half of; it owns this half.
    unowned let element: MountedElement

    /// The element's view; nil for an element drawn by its parent's, or none.
    private(set) var view: GTKView?

    weak var host: GTKRenderer?

    /// Whether the element is fading out: still shown and holding its room, hidden once the fade lands.
    var leaving = false

    init(_ element: MountedElement, host: GTKRenderer) {
        self.element = element
        self.host = host
        view = makeView()
    }

    // MARK: - The element's tree, read through its mounted element

    var type: NodeType { element.type }
    var parent: GTKElement? { element.parent?.gtk }
    var children: [GTKElement] { element.children.map(\.gtk) }
    func value(_ property: Prop) -> HostValue? { element.value(property) }

    // MARK: - The native half's part in a patch

    var presentsView: Bool { view != nil }

    func willApply() {}

    func standingValue(_ property: Prop) -> HostValue? {
        switch (type, property) {
        case (_, .opacity): view.map { .number($0.opacity) }
        case (.slider, .value): (view as? GTKSliderView).map { .number($0.value) }
        default: nil
        }
    }

    func animates(_ property: Prop) -> Bool {
        GTKTransitionSurface.presents(property, on: type)
    }

    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        if wasDescribed, changed.contains(.isVisible) { crossVisibility() }
        applyProperties(changed: changed)
        configureLayoutMotion()
        arrangeChildren()
    }

    func presentFrame(_ changed: Set<Prop>) -> FrameImpact {
        applyProperties(changed: changed)

        var impact = FrameImpact(content: true)
        if view == nil || !changed.isDisjoint(with: Self.arrangedProperties) {
            impact.arrangement = true
        }
        return impact
    }

    func leave() {
        leaving = false
        view?.detach()
    }
}

extension MountedElement {
    /// This element's GTK half.
    var gtk: GTKElement { native as! GTKElement }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The UIKit half of a mounted element: its view, made by the registry, given the element's properties, placed where
/// its layout says and drawn as its transform says.
@MainActor
final class UIKitElement: NativeElement {
    unowned let element: MountedElement

    private(set) var view: UIView?

    /// How the view is moved, turned and scaled over its place, and how opaque it is drawn.
    private(set) var drawing: UIKitViewDrawing?

    weak var host: UIKitRenderer?

    init(_ element: MountedElement, host: UIKitRenderer) {
        self.element = element
        self.host = host
        view = makeView()
        drawing = view.map(UIKitViewDrawing.init)
    }

    // MARK: - The element's tree, read through its mounted element

    var type: NodeType { element.type }
    var parent: UIKitElement? { element.parent?.uiKit }
    var children: [UIKitElement] { element.children.map(\.uiKit) }
    func value(_ property: Prop) -> HostValue? { element.value(property) }

    // MARK: - The native half's part in a patch

    var presentsView: Bool { view != nil }

    func standingValue(_ property: Prop) -> HostValue? {
        switch property {
        case .opacity: drawing.map { .number($0.opacity) }
        default: nil
        }
    }

    func animates(_ property: Prop) -> Bool {
        false
    }

    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        applyProperties(changed: changed)
        arrangeChildren()
    }

    func presentFrame(_ changed: Set<Prop>) -> FrameImpact {
        applyProperties(changed: changed)

        var impact = FrameImpact(content: true)
        let arranged = changed.subtracting(element.ownPlacementRun)
        if view == nil || !arranged.isDisjoint(with: MountedElement.arrangedProperties) {
            impact.arrangement = true
        }
        return impact
    }

    func leave() {}

    var chosenTab: Int? { nil }

    var showsSidebar: Bool? { nil }

    // MARK: - What the user does

    /// An event the view raised, with what it carries, to the handler the tree listens with.
    func send(_ event: Event, _ values: [HostValue]) {
        guard let host else { return }
        element.send(event, values, in: host.runtime)
    }

    /// A value the user changed in the view, by the host layer's rule (`reportUserChange`).
    func report(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host else { return }
        element.reportUserChange(property, event, value, in: host.runtime) { _ in }
    }
}

extension UIKitElement: PlacedView {
    /// Where the view stands in its parent, in points; set, it stands there by its bounds and its centre, which
    /// hold under any transform, and its drawing is composed for its size again.
    var placedFrame: Rect {
        get {
            guard let view else { return Rect(x: 0, y: 0, width: 0, height: 0) }
            let size = view.bounds.size
            return Rect(
                x: view.center.x - size.width / 2, y: view.center.y - size.height / 2, width: size.width,
                height: size.height)
        }
        set {
            guard let view else { return }
            let size = CGSize(width: max(0, newValue.width), height: max(0, newValue.height))
            if view.bounds.size != size { view.bounds.size = size }
            view.center = CGPoint(x: newValue.x + size.width / 2, y: newValue.y + size.height / 2)
            drawing?.compose()
        }
    }
}

extension MountedElement {
    var uiKit: UIKitElement { native as! UIKitElement }
}
#endif

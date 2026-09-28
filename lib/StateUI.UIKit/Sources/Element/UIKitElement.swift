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

    /// The controller UIKit holds a page or an arrangement of pages by; nil for every other element.
    private(set) var controller: UIViewController?

    /// How the view is moved, turned and scaled over its place, and how opaque it is drawn.
    private(set) var drawing: UIKitViewDrawing?

    weak var host: UIKitRenderer?

    /// What the view listens for of the user's input, while it listens for anything.
    var listening: UIKitListening?

    /// Whether the view held the focus when the element last said so.
    var reportedFocus: Bool?

    /// What UIKit asks for the view's context menu, while it has one.
    var contextMenu: UIKitContextMenu?

    /// Whether a layout of StateUI's has placed the view.
    var isPlaced = false

    /// Where a label's place travels: its words stand at that size meanwhile.
    /// Design: docs/design/host/motion.md#words-at-their-destination
    var wordsRoom: Rect?

    /// A menu item's or a toolbar item's action, as UIKit was last handed it.
    var menuAction: UIAction?

    init(_ element: MountedElement, host: UIKitRenderer) {
        self.element = element
        self.host = host
        controller = makeController()
        view = controller.map(\.view) ?? makeView()
        if type == .page { controller = UIKitPageController(page: self) }
        // What StateUI shows takes a press, as a label and a picture of UIKit's do not of themselves.
        view?.isUserInteractionEnabled = true
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
        TransitionSurface.presents(property, on: type)
    }

    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        if wasDescribed, changed.contains(.isVisible) { crossVisibility() }
        applyProperties(changed: changed)
        configureGestures()
        configureContextMenu()
        configureLayoutMotion()
        arrangeChildren()
        arrangePages(changed: changed)
        host?.runtime.frames.follow(self, order: Int64(truncatingIfNeeded: element.mount), reads: readsFrame)
    }

    func presentFrame(_ changed: Set<Prop>) {
        applyProperties(changed: changed)
        // A tab bar takes the bars' colours itself; the window's controller shows the rest of the chrome again.
        if !changed.isDisjoint(with: Self.barColors) {
            let colors = element.barColors
            (controller as? UIKitTabBarController)?.showColors(background: colors.background, foreground: colors.foreground)
        }
    }

    private static let barColors: Set<Prop> = [.barBackgroundColor, .barForegroundColor]

    func leave() {
        host?.runtime.frames.follow(self, order: Int64(truncatingIfNeeded: element.mount), reads: false)
        listening?.detach()
        listening = nil
        releasePages()
    }

}

extension UIKitElement: PlacedView {
    /// Where the view stands in its parent, in points; set, it stands there by its bounds and its centre, which
    /// hold under any transform, and its drawing is composed for its size again - a label at the size its place
    /// travels to, its words standing there meanwhile.
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
            let room = wordsRoom ?? newValue
            let size = CGSize(width: max(0, room.width), height: max(0, room.height))
            if view.bounds.size != size { view.bounds.size = size }
            view.center = CGPoint(x: newValue.x + size.width / 2, y: newValue.y + size.height / 2)
            isPlaced = true
            drawing?.compose()
        }
    }

    func travels(to destination: Rect?) {
        if type == .label { wordsRoom = destination }
    }
}

extension MountedElement {
    var uiKit: UIKitElement { native as! UIKitElement }
}
#endif

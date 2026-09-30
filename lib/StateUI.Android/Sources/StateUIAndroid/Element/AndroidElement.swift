// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The Android half of a mounted element: its native view and everything hung on it.
/// Design: docs/design/host/tree.md#the-native-half
@MainActor
final class AndroidElement: NativeElement {
    /// The element of the mounted tree this is the Android half of; it owns this half.
    unowned let element: MountedElement

    /// The element's view; nil for an element drawn by its parent's, or none.
    private(set) var view: AndroidView?

    weak var host: AndroidRenderer?

    /// Whether a label shows its spans' runs rather than its own words.
    var hasRuns = false

    /// A menu item's or an action's place among the items of the menu it last stood in - its Android item's id,
    /// less one.
    var menuPlace: Int?

    init(_ element: MountedElement, host: AndroidRenderer) {
        self.element = element
        self.host = host
        view = makeView()
    }

    // MARK: - The element's tree, read through its mounted element

    var type: NodeType { element.type }
    var parent: AndroidElement? { element.parent?.android }
    var children: [AndroidElement] { element.children.map(\.android) }
    func value(_ property: Prop) -> HostValue? { element.value(property) }

    // MARK: - The native half's part in a patch

    var presentsView: Bool { view != nil }

    func standingValue(_ property: Prop) -> HostValue? {
        switch (type, property) {
        case (_, .opacity): view.map { .number($0.opacity) }
        case (.slider, .value): (view as? AndroidSliderView).map { .number($0.value) }
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
        view?.setFocusChanged(element.handler(.isFocusedChanged) == nil ? nil : { [weak self] focused in
            self?.send(.isFocusedChanged, [.bool(focused)])
        })
        configureLayoutMotion()
        arrangeChildren()
        arrangePages(changed: changed)
        configureContextMenu()
        host?.runtime.frames.follow(self, order: Int64(truncatingIfNeeded: element.mount), reads: readsFrame)
    }

    func presentFrame(_ changed: Set<Prop>) {
        applyProperties(changed: changed)
        // A bar's colour travels frame by frame: every bar the arrangement's reaches shows each.
        if NodeType.pageTypes.contains(type), !changed.isDisjoint(with: Self.barValues) { refreshBars() }
    }

    func leave() {
        view?.detach()
        host?.runtime.frames.follow(self, order: Int64(truncatingIfNeeded: element.mount), reads: false)
    }
}

extension MountedElement {
    /// This element's Android half.
    var android: AndroidElement { native as! AndroidElement }
}

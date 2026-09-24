// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The Android half of a mounted element: its native view and everything hung on it.
/// Design: docs/design/host/tree.md#the-native-half
@MainActor
final class AndroidElement: NativeElement {
    /// The element of the mounted tree this is the Android half of; it owns this half.
    unowned let element: MountedElement

    /// The element's view; nil for an element drawn by its parent's, or none.
    private(set) var view: AndroidView?

    weak var host: AndroidRenderer?

    /// Whether the element is fading out: still shown and holding its room, hidden once the fade lands.
    var leaving = false

    /// Where the element last said it stood; nil before it said.
    var lastFrameReport: [Double]?

    /// Whether a label shows its spans' runs rather than its own words.
    var hasRuns = false

    /// Where the states a pan carries stood as it started.
    var panFrom = (x: 0.0, y: 0.0)

    /// Whether this page tree is shown, as its pages last heard; and what an arrangement showed before a patch.
    var pagePresented = false
    private var previouslyShown: [MountedElement] = []

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

    func willApply() {
        previouslyShown = shownChildren.map(\.element)
    }

    func standingValue(_ property: Prop) -> HostValue? {
        switch (type, property) {
        case (_, .opacity): view.map { .number($0.opacity) }
        case (.slider, .value): (view as? AndroidSliderView).map { .number($0.value) }
        default: nil
        }
    }

    func animates(_ property: Prop) -> Bool {
        AndroidTransitionSurface.presents(property, on: type)
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
        reconcilePresentation(from: previouslyShown.map(\.android))
        previouslyShown = []
        host?.follow(self, readsFrame: readsFrame)
    }

    func presentFrame(_ changed: Set<Prop>) -> FrameImpact {
        applyProperties(changed: changed)

        var impact = FrameImpact(content: true)
        if view == nil || !changed.subtracting(ownPlacementRun).isDisjoint(with: Self.arrangedProperties) {
            impact.arrangement = true
        }
        return impact
    }

    func leave() {
        leaving = false
        view?.detach()
        host?.follow(self, readsFrame: false)
    }
}

extension MountedElement {
    /// This element's Android half.
    var android: AndroidElement { native as! AndroidElement }
}

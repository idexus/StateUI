// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A SplitView: UIKit's own split view controller, its sidebar the first column and its detail the second - a page
/// standing alone in a column gets the column's own bar. In a narrow room, as on a phone, the sidebar slides over the
/// detail; in a wide one it stands beside it. The sidebar showing or hiding on screen is told, whoever moved it.
/// Design: docs/design/platforms/uikit/pages.md#a-split-view
@MainActor
final class UIKitSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    /// What the controller does when its sidebar showed or hid.
    var onPresentationChanged: ((Bool) -> Void)?

    /// Whether the sidebar shows on screen; nil until UIKit has said.
    private(set) var isPresented: Bool?

    private var shown: (sidebar: UIViewController?, detail: UIViewController?)

    /// Whether the room the split view stands in is narrow, as its presentation last took it; nil before a room.
    private var narrow: Bool?

    /// Whether the sidebar slides over the detail rather than standing beside it.
    var overlays: Bool { narrow == true }

    /// Whether the host is moving the columns itself, which UIKit's telling of it does not report back.
    private var movingItself = false

    /// Whether the application paints the sidebar: it then stands on UIKit's plain column, which UIKit parts from
    /// the detail by its own separator, rather than on UIKit's sidebar material, which stands with none.
    /// Design: docs/design/platforms/uikit/pages.md#a-split-view
    var paintsSidebar = false {
        didSet {
            guard paintsSidebar != oldValue else { return }
            primaryBackgroundStyle = paintsSidebar ? .none : .sidebar
        }
    }

    init() {
        super.init(style: .doubleColumn)
        delegate = self
        // Never one column: in a narrow room the sidebar slides over the detail instead.
        traitOverrides.horizontalSizeClass = .regular
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitSplitViewController is made in code")
    }

    /// The sidebar's controller and the detail's.
    func show(sidebar: UIViewController?, detail: UIViewController?) {
        if sidebar !== shown.sidebar { setViewController(sidebar, for: .primary) }
        if detail !== shown.detail { setViewController(detail, for: .secondary) }
        shown = (sidebar, detail)
        giveTheColumnsTheRoomsWidth()
    }

    /// Shows the sidebar, or hides it, as the tree says - the program's move, which UIKit's telling of it does not
    /// report back.
    func present(_ presented: Bool) {
        guard presented != isPresented else { return }
        isPresented = presented
        // Before a room the columns wait for it: adapting to it lays them as asked.
        guard narrow != nil else { return }
        movingItself = true
        defer { movingItself = false }
        // UIKit's own slide, which moves the columns with a page pushed in the same turn: in a slide the host made
        // itself, that page would grow from nothing.
        presented ? show(.primary) : hide(.primary)
        preferredDisplayMode = askedDisplayMode
    }

    /// How the columns stand for the sidebar the tree asks for: over the detail in a narrow room, beside it in a
    /// wide one, or not at all.
    private var askedDisplayMode: DisplayMode {
        guard isPresented == true else { return .secondaryOnly }
        return narrow == true ? .oneOverSecondary : .oneBesideSecondary
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        adaptToTheRoom()
    }

    /// The room's width class: the split view's own always says wide.
    private var roomIsNarrow: Bool? {
        guard let room = parent?.traitCollection ?? view.window?.windowScene?.traitCollection,
              room.horizontalSizeClass != .unspecified
        else { return nil }
        return room.horizontalSizeClass == .compact
    }

    /// Lays the sidebar over the detail in a narrow room and beside it in a wide one, where the room changed; the
    /// sidebar keeps showing or hiding as it did.
    /// Design: docs/design/platforms/uikit/pages.md#a-split-view
    private func adaptToTheRoom() {
        guard let narrow = roomIsNarrow, narrow != self.narrow else { return }
        self.narrow = narrow
        movingItself = true
        defer { movingItself = false }
        preferredSplitBehavior = narrow ? .overlay : .tile
        preferredDisplayMode = askedDisplayMode
        giveTheColumnsTheRoomsWidth()
        // The sidebar stands on another ground over the detail than beside it.
        showPageBackgrounds()
    }

    /// Each column is as narrow as the room: a tab bar, a sheet and a bar in it stand as the room's own.
    private func giveTheColumnsTheRoomsWidth() {
        for column in children {
            // An override never written is no value to read: reading it throws.
            let overridden = column.traitOverrides.contains(UITraitHorizontalSizeClass.self)
            if narrow == true {
                if !overridden || column.traitOverrides.horizontalSizeClass != .compact {
                    column.traitOverrides.horizontalSizeClass = .compact
                }
            } else if overridden {
                column.traitOverrides.remove(UITraitHorizontalSizeClass.self)
            }
        }
    }

    /// The sidebar showing or hiding on screen is heard as the display mode changes: UIKit tells no column shown or
    /// hidden when the sidebar slides over the detail.
    func splitViewController(
        _ split: UISplitViewController, willChangeTo displayMode: UISplitViewController.DisplayMode
    ) {
        let presented = displayMode != .secondaryOnly
        // What UIKit settles on before the room is known is its own start, not the user's.
        guard presented != isPresented, !movingItself, narrow != nil else { return }
        isPresented = presented
        onPresentationChanged?(presented)
    }
}
#endif

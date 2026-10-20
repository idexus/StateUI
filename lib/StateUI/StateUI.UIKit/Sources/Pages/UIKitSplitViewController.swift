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

    /// UIKit's slide of the sidebar beside the detail, which the detail's pages follow; nil before the split is
    /// mounted.
    private(set) var slide: SplitSlide?

    /// The pages a slide stood apart from the sidebar, cleared as it rests.
    private let slidPages = NSHashTable<UIKitPageController>.weakObjects()

    /// Whether the application paints the sidebar: a line of UIKit's separator colour then parts it from the detail
    /// (`separator`). It stands on UIKit's sidebar material all the same, under which the detail's column slides
    /// with the sidebar; on UIKit's plain column, which parts them by its own line, the detail jumps to its width.
    /// Design: docs/design/platforms/uikit/pages.md#a-split-view
    var paintsSidebar = false {
        didSet {
            guard paintsSidebar != oldValue else { return }
            placeSeparator()
        }
    }

    /// The line down a painted sidebar's edge beside the detail, one point of UIKit's separator colour.
    let separator: UIView = {
        let line = UIView()
        line.backgroundColor = .opaqueSeparator
        line.isUserInteractionEnabled = false
        line.translatesAutoresizingMaskIntoConstraints = false
        return line
    }()

    /// Stands the line down the edge of the sidebar's column while the application paints it, and takes it away
    /// while not.
    private func placeSeparator() {
        separator.removeFromSuperview()
        guard paintsSidebar, let sidebar = viewController(for: .primary)?.view else { return }
        sidebar.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            separator.topAnchor.constraint(equalTo: sidebar.topAnchor),
            separator.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),
        ])
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
        if sidebar !== shown.sidebar { placeSeparator() }
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Over whatever the sidebar's page stands it in since.
        separator.superview?.bringSubviewToFront(separator)
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
        if narrow == false { slideTheDetail(shown: displayMode != .secondaryOnly) }
        let presented = displayMode != .secondaryOnly
        // What UIKit settles on before the room is known is its own start, not the user's.
        guard presented != isPresented, !movingItself, narrow != nil else { return }
        isPresented = presented
        onPresentationChanged?(presented)
    }
}
extension UIKitSplitViewController {
    /// The motion UIKit slides a sidebar beside its detail by: a spring answering in 340 ms, at rest without
    /// overshooting.
    /// Design: docs/design/platforms/uikit/pages.md#a-split-view
    static let sidebarMotion = Motion.spring(response: .milliseconds(340))

    /// Follows UIKit's slide of the sidebar on `sidebarSlide`, the split mounted as `mount`: as UIKit gives the detail
    /// at once the safe area of where the sidebar is going, the detail's shown pages stand as far from their leading
    /// edge as the sidebar has come, frame by frame in UIKit's motion, so they narrow and widen with it.
    /// Design: docs/design/platforms/uikit/pages.md#a-split-view
    func slide(on sidebarSlide: SidebarSlide, mount: UInt64) {
        guard slide == nil else { return }
        let slide = SplitSlide(slide: sidebarSlide, mount: mount, width: 320, following: Self.sidebarMotion)
        slide.stand = { [weak self] pane, _ in self?.standTheDetail(pane, rested: false) }
        slide.rest = { [weak self] _ in self?.standTheDetail(0, rested: true) }
        self.slide = slide
    }

    /// UIKit sets out to slide the sidebar in where `shown`, else out.
    private func slideTheDetail(shown: Bool) {
        guard let slide, let width = viewController(for: .primary)?.view.bounds.width else { return }
        slide.columnStood(width)
        slide.slide(to: shown)
    }

    /// Stands the detail's shown pages `inset` from their leading edge, or by their safe area once the slide rests.
    private func standTheDetail(_ inset: Double, rested: Bool) {
        let pages = viewController(for: .secondary).map(Self.shownPages) ?? []
        for page in pages { slidPages.add(page) }
        // Each page lays out once in the frame's layout pass, however often the frame tells it.
        for page in slidPages.allObjects { page.slidingInset = rested ? nil : inset }
        if rested { slidPages.removeAllObjects() }
    }

    /// Each page stands by its safe area again as the split leaves the tree - the host layer ends its slide.
    func stopSliding() {
        standTheDetail(0, rested: true)
    }

    /// The pages a controller shows now: a stack's top, a tabbed view's chosen tab, or the page itself.
    private static func shownPages(in controller: UIViewController) -> [UIKitPageController] {
        if let page = controller as? UIKitPageController { return [page] }
        if let stack = controller as? UINavigationController {
            return stack.topViewController.map(shownPages) ?? []
        }
        if let tabs = controller as? UITabBarController {
            return tabs.selectedViewController.map(shownPages) ?? []
        }
        return controller.children.flatMap(shownPages)
    }
}

#endif

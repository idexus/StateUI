// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// AppKit's presentation of a split view: the sidebar page in a native
/// sidebar, the detail page beside it.
///
/// The split view spans the whole window, under the title bar and toolbar, so
/// the sidebar runs the window's full height as a Mac sidebar does; each pane
/// keeps its page out of the part the title bar covers. The window's toolbar
/// carries the system sidebar toggle and a separator that tracks the divider.
/// Whether the sidebar shows is StateUI's binding. The host's one adaptation
/// is that a window wide enough for both panes opens with it shown; after
/// that, the user and the application decide.
@MainActor
final class AppKitSplitView: AppKitHitTestView {
    var onPresentationChanged: ((Bool) -> Void)?

    /// The native split view controller the window's toolbar toggles.
    let splitController = NSSplitViewController()

    /// The width at which a window opens with both panes shown.
    private static let sidebarRoom: CGFloat = 720

    private let sidebarController = NSViewController()
    private let detailController = NSViewController()
    private let sidebarSurface = AppKitPaneView()
    private let detailSurface = AppKitPaneView()
    private lazy var sidebarItem = NSSplitViewItem(
        sidebarWithViewController: sidebarController)
    private lazy var detailItem = NSSplitViewItem(
        viewController: detailController)
    private var requestedPresentation = false
    private var lastEffectivePresentation = false
    private var adapted = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        sidebarSurface.insetsBySafeArea = true
        detailSurface.insetsBySafeArea = true
        sidebarController.view = sidebarSurface
        detailController.view = detailSurface
        sidebarItem.canCollapse = true
        sidebarItem.allowsFullHeightLayout = true
        sidebarItem.minimumThickness = 260
        sidebarItem.maximumThickness = 340
        splitController.addSplitViewItem(sidebarItem)
        splitController.addSplitViewItem(detailItem)
        splitController.splitView.isVertical = true
        splitController.splitView.dividerStyle = .thin
        splitController.splitView.translatesAutoresizingMaskIntoConstraints = true
        splitController.splitView.autoresizingMask = [.width, .height]
        splitController.view.translatesAutoresizingMaskIntoConstraints = true
        addSubview(splitController.view)

        ProgramWrite.perform {
            sidebarItem.isCollapsed = true
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(splitViewResized(_:)),
            name: NSSplitView.didResizeSubviewsNotification,
            object: splitController.splitView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitSplitView is created in code")
    }

    override var isFlipped: Bool { true }

    /// Shows a row across the top of the detail - the tabs of a tabbed view
    /// standing in it - as the detail item's own accessory, or takes it away.
    func setDetailRow(_ row: NSView?) {
        let standing = detailItem.topAlignedAccessoryViewControllers.first?.view
        guard standing !== row else { return }

        if !detailItem.topAlignedAccessoryViewControllers.isEmpty {
            detailItem.removeTopAlignedAccessoryViewController(at: 0)
        }
        if let row {
            let accessory = NSSplitViewItemAccessoryViewController()
            accessory.view = row
            // The row stands over the page rather than on a band of its own:
            // a soft edge lets the page show beneath the tabs.
            if #available(macOS 26.1, *) { accessory.preferredScrollEdgeEffectStyle = .soft }
            detailItem.addTopAlignedAccessoryViewController(accessory)
        }

        // The row changes the detail's safe area, which lays nothing out: once
        // AppKit has placed the row, the detail lays its page out again in it.
        splitController.splitView.layoutSubtreeIfNeeded()
        detailSurface.needsLayout = true
    }

    /// Paints the part of the detail the window's bars cover in the colour
    /// written for them, or leaves it to the system's material.
    func setDetailBarColor(_ color: NSColor?) {
        detailSurface.barColor = color
    }

    var detailBarColorForTesting: NSColor? { detailSurface.barColor }
    var sidebarBarColorForTesting: NSColor? { sidebarSurface.barColor }

    var detailRowForTesting: NSView? {
        detailItem.topAlignedAccessoryViewControllers.first?.view
    }

    var detailRowAccessoryForTesting: NSSplitViewItemAccessoryViewController? {
        detailItem.topAlignedAccessoryViewControllers.first
    }

    func setItems(_ items: [AppKitLayoutItem]) {
        let sidebar = items.first
        let detail = items.count > 1 ? items[1] : nil

        // THE PANES IT HAS: a patch on its way to a page applies this view
        // again, and that asks nothing of it.
        guard !AppKitLayoutItem.sameArrangement(sidebarSurface.item, sidebar)
            || !AppKitLayoutItem.sameArrangement(detailSurface.item, detail)
        else { return }

        sidebarSurface.setItem(sidebar)
        detailSurface.setItem(detail)
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    /// Applies Swift's value without echoing it back as a user's change.
    func apply(presented: Bool) {
        requestedPresentation = presented
        setSidebarPresented(presented, reporting: false)
    }

    override var intrinsicContentSize: NSSize {
        let sidebar = sidebarSurface.intrinsicContentSize
        let detail = detailSurface.intrinsicContentSize
        let divider = splitController.splitView.dividerThickness
        return NSSize(
            width: max(detail.width, sidebar.width + divider + detail.width),
            height: max(sidebar.height, detail.height))
    }

    override func layout() {
        super.layout()
        splitController.view.frame = bounds
        adaptToFirstRoom()
        splitController.view.layoutSubtreeIfNeeded()

        // A detached NSSplitViewController has no parent view controller to
        // constrain its split view. AppKit otherwise keeps the panes at their
        // fitting height, allowing a tall document to escape above this host
        // surface. The native split view owns pane layout within these bounds.
        splitController.splitView.frame = splitController.view.bounds
        splitController.splitView.needsLayout = true
        splitController.splitView.layoutSubtreeIfNeeded()
    }

    /// The host's one adaptation: a window wide enough for both panes opens
    /// with its sidebar shown, and reports it to the binding.
    private func adaptToFirstRoom() {
        guard !adapted, bounds.width > 0 else { return }
        adapted = true
        guard !requestedPresentation, bounds.width >= Self.sidebarRoom else { return }

        requestedPresentation = true
        setSidebarPresented(true, reporting: true)
    }

    private func setSidebarPresented(_ presented: Bool, reporting: Bool) {
        let previous = !sidebarItem.isCollapsed
        guard previous != presented else {
            lastEffectivePresentation = presented
            return
        }

        ProgramWrite.perform {
            sidebarItem.isCollapsed = !presented
        }
        lastEffectivePresentation = presented

        if reporting {
            onPresentationChanged?(presented)
        }
    }

    @objc private func splitViewResized(_ notification: Notification) {
        guard !ProgramWrite.isWriting else { return }
        let presented = !sidebarItem.isCollapsed
        guard presented != lastEffectivePresentation else { return }

        requestedPresentation = presented
        lastEffectivePresentation = presented
        onPresentationChanged?(presented)
    }

    var isEffectivelyPresented: Bool { !sidebarItem.isCollapsed }
    var isEffectivelyPresentedForTesting: Bool { isEffectivelyPresented }
    var sidebarWidthForTesting: CGFloat {
        splitController.splitView.subviews.first?.frame.width ?? 0
    }

    /// What the user's sidebar toggle leaves behind, without its animation.
    func toggleForTesting() {
        sidebarItem.isCollapsed.toggle()
    }
}

#endif

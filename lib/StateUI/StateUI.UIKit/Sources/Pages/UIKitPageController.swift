// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page as UIKit's controllers hold it: its view standing within the safe area the bars leave - out to the screen's
/// edge where its content lets itself under them (`SafeAreaArithmetic`) - its background behind the bars too, its bar
/// item what the page says of its bar.
/// Design: docs/design/platforms/uikit/pages.md
@MainActor
final class UIKitPageController: UIViewController, UIKitSheetStanding {
    /// What runs once the controller has left the screen, as a sheet (`UIKitSheetStanding`).
    var leftScreen: (() -> Void)?

    /// The page's element, which stands its view.
    private weak var page: UIKitElement?

    /// The blur or glass a sidebar page stands on, under what it shows; nil while it stands on a color.
    private var ground: (view: UIKitBackdropView, material: HostMaterial)?

    init(page: UIKitElement) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitPageController is made in code")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        leftScreen?()
    }

    override func loadView() {
        view = UIView()
        showBackground()
        if let shown = page?.view { view.addSubview(shown) }
    }

    /// The page's background - its own, else its arrangement's (`pageBackground`) - behind the whole screen it stands
    /// on, the bars and the notch included; where the page says none, a sidebar's ground, else the window's - what the window is made of under a page that paints nothing
    /// of its own - else the system's.
    /// Design: docs/design/platforms/uikit/pages.md#a-pages-background
    func showBackground() {
        let element = page?.element
        let background = HostMaterial(element?.pageBackground).painted.flatMap { HostBrush($0).firstColor }
        let sidebar = background == nil ? sidebarMaterial(of: element) : nil
        showGround(sidebar.flatMap { $0.material.blur == nil ? nil : $0.material })
        view.backgroundColor = background.flatMap(UIColor.init(stateUI:))
            ?? (ground == nil ? sidebar.flatMap(Self.ground(of:)) : .clear)
            ?? view.window?.backgroundColor ?? .systemBackground
    }

    /// The split view's material for the place its sidebar page stands in, and whether that is over the detail; nil
    /// for a page that is no sidebar.
    /// Design: docs/design/host/pages.md#a-sidebars-material
    private func sidebarMaterial(of element: MountedElement?) -> (material: HostMaterial, over: Bool)? {
        guard let element, let split = element.placingParent, split.type == .splitView,
              split.arrangedChildren.first === element,
              let controller = splitViewController as? UIKitSplitViewController
        else { return nil }
        return (split.sidebarMaterial(over: controller.overlays), controller.overlays)
    }

    /// The color a sidebar page stands on: its material's, else over the detail the system's background, never the
    /// window's; nil beside the detail where the split view says nothing.
    private static func ground(of sidebar: (material: HostMaterial, over: Bool)) -> UIColor? {
        sidebar.material.painted.flatMap { HostBrush($0).firstColor }.flatMap(UIColor.init(stateUI:))
            ?? (sidebar.over ? .systemBackground : nil)
    }

    /// Lays `material`'s blur or glass under what the page shows - a blur's tint washed over it, glass tinted in
    /// itself - or takes it away for nil.
    /// Design: docs/design/platforms/uikit/pages.md#a-split-view
    private func showGround(_ material: HostMaterial?) {
        guard let material else {
            ground?.view.removeFromSuperview()
            ground = nil
            return
        }
        let shown = ground?.view ?? UIKitBackdropView()
        if ground == nil { view.insertSubview(shown, at: 0) }
        ground = (shown, material)
        layGround()
    }

    /// The ground across the page's whole view, as large as it now stands.
    private func layGround() {
        guard let (shown, material) = ground else { return }
        shown.frame = view.bounds
        shown.show(material, as: .rounded([0, 0, 0, 0]))
        let wash = shown.showsGlass ? UIKitBrush() : UIKitBrush(material.paint)
        shown.lay(wash, stroke: UIKitBrush(), width: 0, over: view.bounds, along: .rectangle)
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        showBackground()
    }

    /// The safe area the page's content stands in: clear of the screen's bars, the notch, and the window's own
    /// controls in its corner - an iPad's window - which a bar over the page stands clear of already.
    var safeInsets: UIEdgeInsets {
        view.edgeInsets(for: .safeArea(cornerAdaptation: .vertical))
    }

    /// How far the page's room stands from its leading edge while a sidebar slides beside it - as far as the sidebar
    /// has come - in place of the safe area UIKit gives at once for where the sidebar is going; nil for none.
    /// Design: docs/design/platforms/uikit/pages.md#a-split-view
    var slidingInset: CGFloat? {
        didSet { if slidingInset != oldValue { view.setNeedsLayout() } }
    }

    /// Whether the page's leading edge is its right one.
    private var leadsRight: Bool { view.effectiveUserInterfaceLayoutDirection == .rightToLeft }

    /// How far the page's safe area stands from its leading edge.
    var leadingSafeInset: Double { leadsRight ? safeInsets.right : safeInsets.left }

    /// The page's safe insets, the leading one where a sidebar sliding beside it stands.
    private var insets: UIEdgeInsets {
        var insets = safeInsets
        if let inset = slidingInset {
            if leadsRight { insets.right = inset } else { insets.left = inset }
        }
        return insets
    }

    /// Whether a split view's sidebar stands beside this page - in its detail - rather than over it, or slides so.
    private var standsBesideASidebar: Bool {
        guard let split = splitViewController, let detail = split.viewController(for: .secondary),
              slidingInset != nil || [.oneBesideSecondary, .twoBesideSecondary].contains(split.displayMode)
        else { return false }
        var controller: UIViewController? = self
        while let shown = controller, shown !== detail { controller = shown.parent }
        return controller != nil
    }

    /// The whole room the page stands in: its view, but for a sidebar beside it - UIKit lays the detail under that
    /// column, which is no part of what the page runs under.
    private var whole: CGRect {
        guard standsBesideASidebar else { return view.bounds }
        var beside = UIEdgeInsets.zero
        if leadsRight { beside.right = insets.right } else { beside.left = insets.left }
        return view.bounds.inset(by: beside)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layGround()
        // The bars over the page are its safe area's as the screen's are: content stands clear of them, or under.
        // Design: docs/design/host/layout.md#the-safe-area
        let (inside, whole) = (view.bounds.inset(by: insets), whole)
        let safe = Rect(x: inside.minX, y: inside.minY, width: inside.width, height: inside.height)
        let room = SafeAreaArithmetic.room(
            safe: safe, whole: Rect(x: whole.minX, y: whole.minY, width: whole.width, height: whole.height),
            edges: page?.element.contentIgnoresSafeArea ?? .none, direction: page?.element.layoutDirection ?? .leftToRight)
        page?.placedFrame = room
        (page?.element.pageScroller?.uiKit.view as? UIKitScrollView)?.keepClear(
            SafeAreaArithmetic.clearance(room: room, safe: safe))
        page?.view?.layoutIfNeeded()
        // What reads a frame says where it stands within this pass, and what that moves is laid out again: a room
        // UIKit alone narrowed - a sidebar sliding - places its layout in the frame that measured it.
        // Design: docs/design/host/runtime.md#where-a-view-stands
        if page?.host?.runtime.frames.reportLaidOut() == true { page?.view?.layoutIfNeeded() }
    }
}

extension UIViewController {
    /// Has every page under this controller - its children, and what it presents - show its background again.
    func showPageBackgrounds() {
        (self as? UIKitPageController)?.showBackground()
        for child in children { child.showPageBackgrounds() }
        presentedViewController?.showPageBackgrounds()
    }
}
#endif

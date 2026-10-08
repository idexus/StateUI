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
final class UIKitPageController: UIViewController {
    /// The page's element, which stands its view.
    private weak var page: UIKitElement?

    /// The blur or glass a sidebar page stands on, under what it shows; nil while it stands on a colour.
    private var ground: (view: UIKitBackdropView, material: HostMaterial)?

    init(page: UIKitElement) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitPageController is made in code")
    }

    override func loadView() {
        view = UIView()
        showBackground()
        if let shown = page?.view { view.addSubview(shown) }
    }

    /// The room UIKit's own bars take over the page's view - a stack's bar above, the tabs below - which its content
    /// never stands under: only the screen's bars and notch are the safe area's to give.
    private var barsOver: UIEdgeInsets {
        func covered(by bar: UIView?) -> CGRect? {
            guard let bar, !bar.isHidden, bar.window != nil else { return nil }
            return view.convert(bar.bounds, from: bar).intersection(view.bounds)
        }
        var over = UIEdgeInsets.zero
        if navigationController?.isNavigationBarHidden == false,
           let bar = covered(by: navigationController?.navigationBar), !bar.isNull {
            over.top = max(0, bar.maxY)
        }
        if let tabs = covered(by: tabBarController?.tabBar), !tabs.isNull, tabs.height > 0 {
            over.bottom = max(0, view.bounds.maxY - tabs.minY)
        }
        return over
    }

    /// The page's background behind the whole screen it stands on, the bars and the notch included; where the page
    /// says none, a sidebar's ground, else the window's - what the window is made of under a page that paints nothing
    /// of its own - else the system's.
    /// Design: docs/design/platforms/uikit/pages.md#a-pages-background
    func showBackground() {
        let element = page?.element
        let background = HostMaterial(element?.value(.background)).painted.flatMap { HostBrush($0).firstColor }
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
        guard let element, let split = element.parent, split.type == .splitView, split.children.first === element,
              let controller = splitViewController as? UIKitSplitViewController
        else { return nil }
        return (split.sidebarMaterial(over: controller.overlays), controller.overlays)
    }

    /// The colour a sidebar page stands on: its material's, else over the detail the system's background, never the
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
        shown.show(material)
        layGround()
    }

    /// The ground across the page's whole view, as large as it now stands.
    private func layGround() {
        guard let (shown, material) = ground else { return }
        let wash = material.glass == nil ? UIKitBrush(material.paint) : UIKitBrush()
        shown.lay(wash, stroke: UIKitBrush(), width: 0, over: view.bounds, cut: .rectangle)
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layGround()
        let (safe, whole) = (view.bounds.inset(by: safeInsets), view.bounds.inset(by: barsOver))
        let room = SafeAreaArithmetic.room(
            safe: Rect(x: safe.minX, y: safe.minY, width: safe.width, height: safe.height),
            whole: Rect(x: whole.minX, y: whole.minY, width: whole.width, height: whole.height),
            edges: page?.element.contentSafeArea)
        page?.placedFrame = room
        let clearance = SafeAreaArithmetic.endClearance(
            room: room, safe: Rect(x: safe.minX, y: safe.minY, width: safe.width, height: safe.height))
        (page?.element.pageScroller?.uiKit.view as? UIKitScrollView)?.keepEndClear(
            right: clearance.right, bottom: clearance.bottom)
        page?.view?.layoutIfNeeded()
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

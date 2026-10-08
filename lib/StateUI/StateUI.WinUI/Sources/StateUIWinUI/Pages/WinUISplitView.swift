// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A SplitView: the sidebar page in WinUI's own navigation pane - beside the detail page where the window is wide,
/// over it and closed by a click beside it where it is narrow - which WinUI places, as it places any Windows app's.
/// Whether the sidebar shows is StateUI's binding, which the window's chrome toggles and which follows what WinUI
/// shows. The host's one adaptation is that a window wide enough for both panes opens with the sidebar shown; after
/// that, the user and the application decide.
/// Design: docs/design/platforms/winui/pages.md#a-split-view
@MainActor
final class WinUISplitView: WinUILayoutView {
    /// Whether the sidebar shows.
    private(set) var isPresented = false

    /// What the split does when the sidebar shows or hides of its own accord - its first room, a click beside it,
    /// the window's room changing.
    var onPresentationChanged: ((Bool) -> Void)?

    /// WinUI's navigation view, whose pane is the sidebar.
    let sidebar = WinUISidebarView()

    /// The sidebar page and the detail page, as the tree gives them, and the row across the detail.
    private var pages: [WinUILayoutItem] = []
    private(set) weak var detailRow: WinUIView?

    /// The size WinUI's navigation view was last arranged at, which it is measured at too; and what it last asked.
    private var arranged: LayoutSize?
    private var asked = LayoutSize.zero
    private var adaptation = SidebarAdaptation()

    /// The materials the split view says for its sidebar beside the detail and over it.
    var grounds = (beside: HostMaterial(nil), over: HostMaterial(nil)) {
        didSet { paintPane() }
    }

    /// The grounds the pane last stood on, once it stood on any.
    private var painted: (beside: PaneGround, over: PaneGround)?

    override init() {
        super.init()
        sidebar.placingLayout = self
        sidebar.onPresented = { [weak self] open in
            guard let self, open != isPresented else { return }
            isPresented = open
            onPresentationChanged?(open)
        }
        setChildren([sidebar])
    }

    /// The pages go in WinUI's navigation view, which places them; the panel holds it alone.
    @discardableResult
    override func setItems(_ items: [WinUILayoutItem]) -> Bool {
        guard items.count != pages.count || !zip(items, pages).allSatisfy({ $0.view === $1.view }) else { return false }

        pages = items
        for page in items { page.view.placingLayout = nil }
        configure()
        invalidateMeasurements()
        return true
    }

    override func heldViews() -> [WinUIView] {
        [sidebar]
    }

    /// Shows a row across the top of the detail - the tabs of a tabbed view standing in it - or takes it away.
    func setDetailRow(_ row: WinUIView?) {
        guard row !== detailRow else { return }
        detailRow = row
        configure()
    }

    /// Applies the tree's value without echoing it back as a user's change.
    func present(_ presented: Bool) {
        guard presented != isPresented else { return }

        isPresented = presented
        configure()
    }

    /// What WinUI's navigation view asked, never its pages' own sizes: WinUI measures them in the room it gives them.
    override func contentSize(width: Double?) -> LayoutSize {
        asked
    }

    /// Measures WinUI's navigation view at the size it was last arranged at, the one its pages are laid out in.
    /// Design: docs/design/platforms/winui/pages.md#a-native-arrangement
    override func measure(width: Double, height: Double) -> LayoutSize {
        let size = arranged ?? LayoutSize(width: width.isFinite ? width : 0, height: height.isFinite ? height : 0)
        asked = sidebar.measure(width: size.width, height: size.height)
        return super.measure(width: width, height: height)
    }

    override func arrange(in bounds: Rect) {
        let size = LayoutSize(width: bounds.width, height: bounds.height)
        if size != arranged {
            arranged = size
            asked = sidebar.measure(width: size.width, height: size.height)
        }
        adaptToFirstRoom(width: bounds.width)
        sidebar.layout(bounds)
    }

    /// The host's one adaptation: a window wide enough for both panes opens with its sidebar shown, and says so.
    private func adaptToFirstRoom(width: Double) {
        guard adaptation.room(width, breakpoint: WinUISidebarView.expandsAt, shown: isPresented) else { return }

        present(true)
        onPresentationChanged?(true)
    }

    private func configure() {
        ProgramWrite.perform {
            sidebar.set(
                sidebar: pages.first?.view, detail: pages.dropFirst().first?.view, row: detailRow,
                open: isPresented)
        }
        paintPane()
    }

    /// Stands the pane on the split view's material for each place, else on the sidebar page's background - so the
    /// room WinUI keeps around the page shows no window backdrop - else on WinUI's own; said again whenever either
    /// changes.
    /// Design: docs/design/platforms/winui/pages.md#a-split-view
    func paintPane() {
        let page = (pages.first?.view as? WinUILayoutView)?.box.fill?.argb
        let grounds = (beside: PaneGround(grounds.beside, page: page), over: PaneGround(grounds.over, page: page))
        guard painted.map({ $0 != grounds }) ?? true else { return }

        painted = grounds
        let (beside, over) = grounds
        stateui_winui_split_set_pane_grounds(
            sidebar.handle, beside.kind, beside.argb, beside.opacity, beside.tintOpacity,
            over.kind, over.argb, over.opacity, over.tintOpacity)
    }

    override func detach() {
        super.detach()
        onPresentationChanged = nil
        sidebar.detach()
    }
}

/// A ground of WinUI's navigation pane, as the relay takes it: WinUI's own (0), a colour (1), or the in-app acrylic
/// (2) - a blur at its thickness, in its colour, the tint over the theme's.
/// Design: docs/design/platforms/winui/pages.md#a-split-view
struct PaneGround: Equatable {
    var kind: Int32 = 0
    var argb: UInt32 = 0
    var opacity: Float = 0
    var tintOpacity: Float = 0

    /// The ground `material` is, the sidebar page's `page` colour standing in for none.
    @MainActor init(_ material: HostMaterial, page: UInt32?) {
        if let thickness = material.blur, let colour = material.painted.flatMap({ HostBrush($0).firstColor })?.argb {
            let acrylic = WinUIWindow.acrylic(thickness)
            (kind, argb, opacity, tintOpacity) = (2, colour, acrylic.opacity, acrylic.tintOpacity)
        } else if let colour = material.paint.flatMap({ HostBrush($0).firstColor })?.argb ?? page {
            (kind, argb) = (1, colour)
        }
    }
}

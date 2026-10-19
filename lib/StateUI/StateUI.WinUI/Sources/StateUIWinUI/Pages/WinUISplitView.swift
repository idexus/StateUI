// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A SplitView: the sidebar page in WinUI's own split pane - beside the detail page where the window is wide, over it
/// and closed by a click beside it where it is narrow, by the host layer's rule (`SidebarAdaptation`). Whether the
/// sidebar shows is StateUI's binding, which the window's chrome toggles and which follows what WinUI shows. The
/// host's one adaptation is that a window wide enough for both panes opens with the sidebar shown; after that, the
/// user and the application decide - but a sidebar beside the detail closes as the window narrows it over.
/// Design: docs/design/platforms/winui/pages.md#a-split-view
@MainActor
final class WinUISplitView: WinUILayoutView {
    /// Whether the sidebar shows.
    private(set) var isPresented = false

    /// What the split does when the sidebar shows or hides of its own accord - its first room, a click beside it,
    /// the window's room changing.
    var onPresentationChanged: ((Bool) -> Void)?

    /// WinUI's split view, whose pane is the sidebar.
    let sidebar = WinUISidebarView()

    /// Whether the sidebar stands beside the detail.
    private var beside = false

    /// Whether the sidebar lies over the detail, as the room was when the split was last laid out.
    var overlays: Bool { !beside }

    /// The sidebar page and the detail page, as the tree gives them, and the row across the detail.
    private var pages: [WinUILayoutItem] = []
    private(set) weak var detailRow: WinUIView?

    /// The size WinUI's split view was last arranged at, which it is measured at too; and what it last asked.
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
        paneWidth = sidebar.paneWidth
        sidebar.onPresented = { [weak self] open in
            guard let self, open != isPresented else { return }
            isPresented = open
            onPresentationChanged?(open)
            // A pane WinUI closes of its own accord stays open while it slides out.
            if !open { slideToPresentation() }
        }
        setChildren([sidebar])
    }

    /// The pages go in WinUI's split view, which places them; the panel holds it alone.
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

    /// The sidebar's slide on the runtime's frames; nil before the split is in the tree, when it shows and hides at
    /// once.
    private(set) var slide: SplitSlide?

    /// The pane's whole width: the theme's, as WinUI opens it, read before anything changes it.
    private var paneWidth = 0.0

    /// Slides the sidebar on `sidebarSlide`, the split mounted as `mount`: in, its pane opens at none wide; each frame
    /// it stands as wide as the slide has come, the detail beside it taking every width between; out, it closes.
    func slide(on sidebarSlide: SidebarSlide, mount: UInt64) {
        guard slide == nil else { return }
        let slide = SplitSlide(slide: sidebarSlide, mount: mount, width: paneWidth)
        slide.begin = { [weak self] shows in if shows { self?.configure() } }
        slide.stand = { [weak self] pane, page in self?.sidebar.slide(pane: pane, width: page) }
        slide.rest = { [weak self] shown in if !shown { self?.configure() } }
        self.slide = slide
    }

    /// Applies the tree's value without echoing it back as a user's change.
    func present(_ presented: Bool) {
        guard presented != isPresented else { return }

        isPresented = presented
        slideToPresentation()
    }

    /// Slides the sidebar in or out by the pane's width, frame by frame; WinUI slides one in over the detail itself,
    /// which keeps its width; one not placed yet stands at once.
    /// Design: docs/design/platforms/winui/pages.md#a-split-view
    private func slideToPresentation() {
        guard let slide, arranged != nil, beside || !isPresented else { return configure() }
        slide.slide(to: isPresented)
    }

    /// What WinUI's split view asked, never its pages' own sizes: WinUI measures them in the room it gives them.
    override func contentSize(width: Double?) -> LayoutSize {
        asked
    }

    /// Measures WinUI's split view at the size it was last arranged at, the one its pages are laid out in.
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
        adaptToRoom(width: bounds.width)
        sidebar.layout(bounds)
    }

    /// Places the sidebar for the room by the host layer's rule: beside the detail or over it - one beside it closing
    /// as the window narrows it over, said as the user's - and a window wide enough for both panes first opening with
    /// its sidebar shown.
    private func adaptToRoom(width: Double) {
        guard width > 0 else { return }
        let place = adaptation.place(width, breakpoint: WinUISidebarView.expandsAt, shown: isPresented)
        let opens = adaptation.room(width, breakpoint: WinUISidebarView.expandsAt, shown: isPresented)
        guard place.beside != beside || place.closes || opens else { return }

        beside = place.beside
        if place.closes || opens {
            isPresented = opens
            onPresentationChanged?(opens)
        }
        configure()
    }

    /// Shows the pages, the pane open or closed as the sidebar is - a closed pane none wide, the width a slide opens
    /// from and nothing a close WinUI tells late could keep open; an open one, unless it slides, at its whole width
    /// before it opens - and the pane's grounds.
    private func configure() {
        ProgramWrite.perform {
            if slide?.target == nil { sidebar.slide(pane: isPresented ? paneWidth : 0, width: paneWidth) }
            sidebar.set(
                sidebar: pages.first?.view, detail: pages.dropFirst().first?.view, row: detailRow,
                open: isPresented, beside: beside)
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

/// A ground of WinUI's split pane, as the relay takes it: WinUI's own, a colour, or the in-app acrylic - a blur at its
/// thickness, in its colour, the tint over the theme's.
/// Design: docs/design/platforms/winui/pages.md#a-split-view
struct PaneGround: Equatable {
    var kind: StateUIGround = .own
    var argb: UInt32 = 0
    var opacity: Float = 0
    var tintOpacity: Float = 0

    /// The ground `material` is, the sidebar page's `page` colour standing in for none.
    @MainActor init(_ material: HostMaterial, page: UInt32?) {
        if let thickness = material.blur, let colour = material.painted.flatMap({ HostBrush($0).firstColor })?.argb {
            let acrylic = WinUIWindow.acrylic(thickness)
            (kind, argb, opacity, tintOpacity) = (.acrylic, colour, acrylic.opacity, acrylic.tintOpacity)
        } else if let colour = material.paint.flatMap({ HostBrush($0).firstColor })?.argb ?? page {
            (kind, argb) = (.colour, colour)
        }
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A SplitView: libadwaita's `AdwOverlaySplitView` - the sidebar beside the detail where the window is wide, over
/// it where it is narrow - each pane a page in a frame with its own header bar, or an arrangement carrying its own.
/// Whether the sidebar shows is StateUI's binding, which the detail's toggle changes and which follows what GTK
/// shows. A window wide enough for both panes opens with the sidebar shown.
/// Design: docs/design/platforms/gtk/pages.md#a-split-view
@MainActor
final class GTKSplitView: GTKLayoutView {
    /// Whether the sidebar shows.
    private(set) var isPresented = false

    /// Whether the split stands collapsed, the sidebar over the detail.
    var isCollapsed: Bool { adw_overlay_split_view_get_collapsed(native) != 0 }

    /// What the split does when the sidebar shows or hides of its own accord - its first room, a click beside it,
    /// a swipe.
    var onPresentationChanged: ((Bool) -> Void)?

    /// Which of the panes' views are framed: a page, a tabbed view.
    var framedPanes: [Bool] = []

    /// The frames of the panes that are framed: the sidebar's, the detail's.
    private(set) var sidebarFrame: GTKPageFrame?
    private(set) var detailFrame: GTKPageFrame?

    private let split = GTKWidgetView { adw_overlay_split_view_new() }
    private var panes: [GTKView] = []
    private var adapted = false

    override init() {
        super.init()
        split.placingLayout = self
        setChildren([split])
        connectNotify(UnsafeMutableRawPointer(split.widget), "show-sidebar", number: number) { _, _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKSplitView)?.sidebarMoved() }
        }
    }

    private var native: OpaquePointer { split.widget.opaque }

    /// The sidebar and the detail, each framed where it is a page.
    @discardableResult
    override func setItems(_ items: [GTKLayoutItem]) -> Bool {
        let views = items.map(\.view)
        guard views.count != panes.count || !zip(views, panes).allSatisfy({ $0 === $1 }) else { return false }

        panes = views
        for view in views { view.placingLayout = nil }
        sidebarFrame = frame(views.first, framed: framedPanes.first == true, keeping: sidebarFrame)
        detailFrame = frame(views.dropFirst().first, framed: framedPanes.dropFirst().first == true, keeping: detailFrame)
        adw_overlay_split_view_set_sidebar(native, sidebarFrame?.widget ?? views.first?.widget)
        adw_overlay_split_view_set_content(native, detailFrame?.widget ?? views.dropFirst().first?.widget)
        invalidateMeasurements()
        return true
    }

    /// A frame around `view`, the one it stands in already where it does.
    private func frame(_ view: GTKView?, framed: Bool, keeping kept: GTKPageFrame?) -> GTKPageFrame? {
        guard let view, framed else { return nil }
        return kept?.page === view ? kept : GTKPageFrame(page: view)
    }

    /// Shows or hides the sidebar, as the program's move.
    func present(_ shows: Bool) {
        isPresented = shows
        ProgramWrite.perform { adw_overlay_split_view_set_show_sidebar(native, shows ? 1 : 0) }
    }

    /// The sidebar showed or hid of its own accord: said, where it was not the program's.
    private func sidebarMoved() {
        let shows = adw_overlay_split_view_get_show_sidebar(native) != 0
        guard !ProgramWrite.isWriting, shows != isPresented else { return }
        isPresented = shows
        onPresentationChanged?(shows)
    }

    /// Collapses the split in a window narrower than 400sp, as GNOME's applications do - a breakpoint of the
    /// window's, added once the split stands in one.
    /// Design: docs/design/platforms/gtk/pages.md#a-split-view
    func adapt(in window: GTKWidget) {
        guard !adapted else { return }
        adapted = true

        let breakpoint = adw_breakpoint_new(adw_breakpoint_condition_parse("max-width: 400sp"))!
        var collapsed = GValue()
        g_value_init(&collapsed, g_type_from_name("gboolean"))
        g_value_set_boolean(&collapsed, 1)
        adw_breakpoint_add_setter(breakpoint, split.widget.of(GObject.self), "collapsed", &collapsed)
        g_value_unset(&collapsed)
        adw_application_window_add_breakpoint(window.of(AdwApplicationWindow.self), breakpoint)
    }

    /// Opens a split wide enough for both panes with its sidebar shown, once; whether it did.
    func openWide() -> Bool {
        guard !isPresented, !isCollapsed, gtk_widget_get_width(widget) > 0 else { return false }
        present(true)
        return true
    }

    override func contentSize(width: Double?) -> LayoutSize {
        split.measure(width: width, height: nil)
    }

    override func arrange(in bounds: Rect) {
        split.layout(bounds)
    }

    override func detach() {
        super.detach()
        onPresentationChanged = nil
    }
}

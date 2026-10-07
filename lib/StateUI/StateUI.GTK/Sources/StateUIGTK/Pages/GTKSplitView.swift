// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
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

    /// The colours the sidebar stands on beside the detail and over it, as the split view says them; nil for
    /// libadwaita's own sidebar.
    var grounds: (beside: GdkRGBA?, over: GdkRGBA?) = (nil, nil) {
        didSet { ground() }
    }

    /// The fill class the sidebar's widget wears, and the class the split wears for its sidebar's pane.
    private var groundClass: String?
    private var paneClass: String?

    private let split = GTKWidgetView { adw_overlay_split_view_new() }
    private var panes: [GTKView] = []
    private var adapted = false
    private var adaptation = SidebarAdaptation()

    /// Where GNOME's applications collapse a split, in scale-independent pixels: logical pixels at the desktop's
    /// own text scale.
    private static let collapsesAt = 400.0

    override init() {
        super.init()
        split.placingLayout = self
        setChildren([split])
        connectNotify(UnsafeMutableRawPointer(split.widget), "show-sidebar", number: number) { _, _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKSplitView)?.sidebarMoved() }
        }
        connectNotify(UnsafeMutableRawPointer(split.widget), "collapsed", number: number) { _, _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKSplitView)?.ground() }
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
        unground()
        sidebarFrame = frame(views.first, framed: framedPanes.first == true, keeping: sidebarFrame)
        detailFrame = frame(views.dropFirst().first, framed: framedPanes.dropFirst().first == true, keeping: detailFrame)
        adw_overlay_split_view_set_sidebar(native, sidebarFrame?.widget ?? views.first?.widget)
        adw_overlay_split_view_set_content(native, detailFrame?.widget ?? views.dropFirst().first?.widget)
        ground()
        keepTheClosedSidebarOutOfReach()
        invalidateMeasurements()
        return true
    }

    /// Stands the sidebar on the split view's colour for its place - over the detail where the split is collapsed,
    /// beside it otherwise - or on libadwaita's own sidebar.
    /// Design: docs/design/host/pages.md#a-sidebars-material
    private func ground() {
        // Beside the page the pane lets the window through, as a desktop sidebar does; over it, libadwaita's own.
        swapClass(&paneClass, to: isCollapsed ? nil : GTKStyleSheet.sidebarBeside(shaded: grounds.beside == nil),
                  on: split.widget)
        guard let sidebar = adw_overlay_split_view_get_sidebar(native) else { return }
        let colour = isCollapsed ? grounds.over : grounds.beside
        swapClass(&groundClass, to: colour.map(GTKStyleSheet.fill), on: sidebar)
    }

    /// Takes the fill class off the sidebar's widget, while it still stands in the split.
    private func unground() {
        guard let sidebar = adw_overlay_split_view_get_sidebar(native) else { return }
        swapClass(&groundClass, to: nil, on: sidebar)
    }

    /// The split's own widget, which wears its sidebar's pane.
    var splitWidgetForTesting: GTKWidget { split.widget }

    /// The sidebar's widget, which wears its ground.
    var sidebarWidgetForTesting: GTKWidget? { adw_overlay_split_view_get_sidebar(native) }

    /// A closed sidebar takes no focus and is read by nobody: libadwaita slides it past the split's edge and keeps it
    /// shown there, where Tab and a screen reader would still reach what it holds.
    /// Design: docs/design/platforms/gtk/pages.md#a-split-view
    private func keepTheClosedSidebarOutOfReach() {
        guard let sidebar = adw_overlay_split_view_get_sidebar(native) else { return }
        let shows = adw_overlay_split_view_get_show_sidebar(native) != 0
        gtk_widget_set_can_focus(sidebar, shows ? 1 : 0)
        var state = GTK_ACCESSIBLE_STATE_HIDDEN
        var hidden = GValue()
        g_value_init(&hidden, g_type_from_name("gboolean"))
        g_value_set_boolean(&hidden, shows ? 0 : 1)
        gtk_accessible_update_state_value(OpaquePointer(sidebar), 1, &state, &hidden)
        g_value_unset(&hidden)
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

    /// The sidebar showed or hid: out of reach while closed, and said where it was not the program's move.
    private func sidebarMoved() {
        keepTheClosedSidebarOutOfReach()
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

        let breakpoint = adw_breakpoint_new(adw_breakpoint_condition_parse("max-width: \(Int(Self.collapsesAt))sp"))!
        var collapsed = GValue()
        g_value_init(&collapsed, g_type_from_name("gboolean"))
        g_value_set_boolean(&collapsed, 1)
        adw_breakpoint_add_setter(breakpoint, split.widget.of(GObject.self), "collapsed", &collapsed)
        g_value_unset(&collapsed)
        adw_application_window_add_breakpoint(window.of(AdwApplicationWindow.self), breakpoint)
    }

    /// The host's one adaptation (`SidebarAdaptation`): a split first given room wide enough for both panes opens
    /// with its sidebar shown, and says so - once GTK has laid the frame out, not inside its allocation.
    private func adaptToFirstRoom(width: Double) {
        guard adaptation.room(width, breakpoint: Self.breakpoint, shown: isPresented) else { return }
        GTKDoorbell.afterLayout { [weak self] in
            guard let self, !isPresented else { return }
            present(true)
            onPresentationChanged?(true)
        }
    }

    /// The breakpoint in logical pixels: a scale-independent pixel follows the desktop's text scale.
    private static var breakpoint: Double {
        guard let settings = gtk_settings_get_default() else { return collapsesAt }
        var value = GValue()
        g_value_init(&value, g_type_from_name("gint"))
        defer { g_value_unset(&value) }
        g_object_get_property(UnsafeMutablePointer<GObject>(settings), "gtk-xft-dpi", &value)
        let dpi = Double(g_value_get_int(&value))
        return dpi > 0 ? collapsesAt * dpi / (96 * 1024) : collapsesAt
    }

    override func contentSize(width: Double?) -> LayoutSize {
        split.measure(width: width, height: nil)
    }

    override func arrange(in bounds: Rect) {
        split.layout(bounds)
        adaptToFirstRoom(width: bounds.width)
    }

    override func detach() {
        super.detach()
        onPresentationChanged = nil
    }
}

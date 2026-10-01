// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// An ItemsView: a StateUI layout holding GTK's own list view - a `GtkListView` down or across, a `GtkGridView` in
/// columns - in a scrolled window, over a string list of the list's identities; a cell holds each entry's subtree as
/// the list binds it (`ItemsCells`). GTK scrolls, reuses its rows, chooses, activates and tells the screen reader;
/// StateUI builds what a cell holds. The list is a room: it asks for none, and stands where it is put.
/// Design: docs/design/platforms/gtk/items.md
@MainActor
final class GTKItemsView: GTKLayoutView {
    let cells: ItemsCells

    private let scroller = GTKWidgetView { gtk_scrolled_window_new() }

    /// The list view or the grid view, and the choice over the identities it shows.
    private(set) var list: GTKWidget?
    private(set) var selection: OpaquePointer?

    /// The identities, as GTK's string list, and the factory the rows come from.
    private let model: OpaquePointer
    private let factory: OpaquePointer

    private var shape = ItemsLayout.list()
    private var mode = SelectionMode.none
    private var placement: ItemsPlacement?

    /// The width the list was last given.
    private var width = 0.0

    /// Every cell set up, by its list item.
    private(set) var made: [OpaquePointer: GTKItemCell] = [:]

    /// How deep the list is in binding its rows, and what waits for it to be done.
    private var binding = 0
    private var waiting: [() -> Void] = []

    /// Whether the list left the tree: what GTK still says is heard by nobody.
    private var released = false

    /// Whether the entries in view are to be told after the layout under way.
    private var tellsShowing = false

    init(cells: ItemsCells) {
        self.cells = cells
        model = gtk_string_list_new(nil)
        factory = gtk_signal_list_item_factory_new()
        super.init()

        let rows = UnsafeMutableRawPointer(factory)
        connectSignal(rows, "setup", number: number) { (_: UnsafeMutableRawPointer?, item: UnsafeMutableRawPointer?, data: gpointer?) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKItemsView)?.setUp(item) }
        }
        connectSignal(rows, "bind", number: number) { (_: UnsafeMutableRawPointer?, item: UnsafeMutableRawPointer?, data: gpointer?) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKItemsView)?.bind(item) }
        }
        connectSignal(rows, "unbind", number: number) { (_: UnsafeMutableRawPointer?, item: UnsafeMutableRawPointer?, data: gpointer?) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKItemsView)?.unbind(item) }
        }
        connectSignal(rows, "teardown", number: number) { (_: UnsafeMutableRawPointer?, item: UnsafeMutableRawPointer?, data: gpointer?) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKItemsView)?.tearDown(item) }
        }
        let scrolled = scroller.widget.opaque
        for adjustment in [gtk_scrolled_window_get_hadjustment(scrolled), gtk_scrolled_window_get_vadjustment(scrolled)] {
            guard let adjustment else { continue }
            connectSignal(UnsafeMutableRawPointer(adjustment), "value-changed", number: number) { (_: UnsafeMutableRawPointer?, data: gpointer?) in
                MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKItemsView)?.tellShowing() }
            }
        }
        scroller.placingLayout = self
        setChildren([scroller])
        makeList()
    }

    /// The list lets its model and its factory go as it goes.
    isolated deinit {
        g_object_unref(UnsafeMutableRawPointer(model))
        g_object_unref(UnsafeMutableRawPointer(factory))
    }

    // MARK: - What the tree says

    /// The entries, the layout, how many may be chosen and which are.
    func apply(layout: ItemsLayout, mode: SelectionMode) {
        let changes = cells.takeEntries()
        if Self.kind(of: layout) != Self.kind(of: shape) || layout.isAcross != shape.isAcross {
            shape = layout
            makeList()
        } else {
            shape = layout
        }
        if let changes { writeEntries(changes) }
        place()
        if mode != self.mode {
            self.mode = mode
            choose(mode)
        }
        select(cells.selected)
    }

    /// Whether `layout` is a grid, which a list view does not stand.
    private static func kind(of layout: ItemsLayout) -> Int {
        if case .grid = layout { return 1 }
        return 0
    }

    /// The list view for the layout, in the scrolled window: a grid view for a grid, a list view down or across.
    private func makeList() {
        let chosen = choiceModel(mode)
        let factory = OpaquePointer(g_object_ref(UnsafeMutableRawPointer(self.factory)))
        let made: GTKWidget
        if case .grid = shape {
            made = gtk_grid_view_new(chosen, factory)
        } else {
            made = gtk_list_view_new(chosen, factory)
            gtk_orientable_set_orientation(
                made.opaque, shape.isAcross ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL)
        }
        // A row stands at its natural length: at its least, a StateUI panel's nothing, every row fits in view at
        // once. Across the list it stands at the list's own width.
        if shape.isAcross {
            gtk_scrollable_set_hscroll_policy(made.opaque, GTK_SCROLL_NATURAL)
        } else {
            gtk_scrollable_set_vscroll_policy(made.opaque, GTK_SCROLL_NATURAL)
        }
        // What stands under the collection shows behind its rows, as on every host.
        // Design: docs/design/platforms/gtk/items.md#behind-the-rows
        gtk_widget_add_css_class(made, GTKStyleSheet.clear)
        connectSignal(UnsafeMutableRawPointer(made), "activate", number: number) { (_: UnsafeMutableRawPointer?, place: UInt32, data: gpointer?) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKItemsView)?.activated(Int(place)) }
        }
        selection = chosen
        listenToChoice()
        gtk_scrolled_window_set_child(scroller.widget.opaque, made)
        list = made
        placement = nil
    }

    /// A choice over the identities as `mode` says: none, one the user may take back, or many.
    private func choiceModel(_ mode: SelectionMode) -> OpaquePointer {
        let identities = OpaquePointer(g_object_ref(UnsafeMutableRawPointer(model)))
        switch mode {
        case .none:
            return gtk_no_selection_new(identities)
        case .single:
            let one = gtk_single_selection_new(identities)!
            gtk_single_selection_set_autoselect(one, 0)
            gtk_single_selection_set_can_unselect(one, 1)
            return one
        case .multiple:
            return gtk_multi_selection_new(identities)
        }
    }

    /// Another choice over the same identities, as `mode` says.
    private func choose(_ mode: SelectionMode) {
        guard let list else { return }
        let chosen = choiceModel(mode)
        if case .grid = shape {
            gtk_grid_view_set_model(list.opaque, chosen)
        } else {
            gtk_list_view_set_model(list.opaque, chosen)
        }
        g_object_unref(UnsafeMutableRawPointer(chosen))
        selection = chosen
        listenToChoice()
    }

    private func listenToChoice() {
        guard let selection else { return }
        connectSignal(UnsafeMutableRawPointer(selection), "selection-changed", number: number) { (_: UnsafeMutableRawPointer?, _: UInt32, _: UInt32, data: gpointer?) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKItemsView)?.choiceChanged() }
        }
    }

    /// The identities, changed run by run, once the list is done binding its rows.
    private func writeEntries(_ changes: ItemsChanges) {
        let identities = cells.identities
        change { [model] in
            for run in changes.removedRuns {
                gtk_string_list_splice(model, guint(run.lowerBound), guint(run.count), nil)
            }
            for run in changes.insertedRuns {
                withCStrings(identities[run]) { gtk_string_list_splice(model, guint(run.lowerBound), 0, $0) }
            }
        }
    }

    /// Stands each entry as the host layer places it (`ItemsPlacement`): a grid's columns from the width it is given,
    /// and each bound cell's room.
    private func place() {
        let placement = ItemsPlacement(cells.entries, layout: shape, width: width, spanning: false)
        guard placement != self.placement else { return }
        self.placement = placement
        if case .grid = shape, let list {
            gtk_grid_view_set_min_columns(list.opaque, guint(placement.columns))
            gtk_grid_view_set_max_columns(list.opaque, guint(placement.columns))
        }
        for cell in made.values {
            guard let place = cell.place, placement.rooms.indices.contains(place) else { continue }
            cell.keep(placement.rooms[place])
        }
    }

    /// Selects what the tree says is chosen, as the program: nothing is told back. A single choice is its model's
    /// own: GTK's single selection takes no set of items to stand chosen.
    private func select(_ chosen: [String]) {
        guard let selection, mode != .none else { return }
        let wanted = Set(chosen)
        let count = g_list_model_get_n_items(model)
        if mode == .single {
            let place = (0..<count).first { wanted.contains(identity(at: $0)) } ?? guint.max
            return ProgramWrite.perform { gtk_single_selection_set_selected(selection, place) }
        }
        let selected = gtk_bitset_new_empty()
        let every = gtk_bitset_new_range(0, count)
        defer {
            gtk_bitset_unref(selected)
            gtk_bitset_unref(every)
        }
        for place in 0..<count where wanted.contains(identity(at: place)) {
            gtk_bitset_add(selected, place)
        }
        ProgramWrite.perform { _ = gtk_selection_model_set_selection(selection, selected, every) }
    }

    /// Runs `apply` now, or once the list is done binding its rows, after everything waiting before it.
    private func change(_ apply: @escaping () -> Void) {
        guard binding > 0 || !waiting.isEmpty else { return apply() }
        waiting.append(apply)
        guard waiting.count == 1 else { return }
        GTKDoorbell.afterLayout { [weak self] in
            guard let self else { return }
            let waiting = self.waiting
            self.waiting = []
            for apply in waiting { apply() }
        }
    }

    /// The tree's entries changed: every cell shows the subtree its entry has now (`ItemsCells.childrenChanged`).
    func childrenChanged() {
        cells.childrenChanged()
    }

    /// An entry's size would change: the cell holding it is measured again.
    func remeasure(_ item: MountedElement) {
        guard let identity = cells.identity(of: item) else { return }
        (cells.holding(of: identity) as? GTKItemCell)?.invalidateMeasurements()
    }

    // MARK: - Its room

    /// As wide as it is offered and as tall as nothing asks: its room is what its layout gives it.
    override func contentSize(width: Double?) -> LayoutSize {
        LayoutSize(width: width ?? 0, height: 0)
    }

    /// Stands the scrolled window over the whole room; a grid's columns follow the width.
    override func arrange(in bounds: Rect) {
        if bounds.width != width {
            width = bounds.width
            place()
        }
        scroller.layout(bounds)
    }

    // MARK: - What the list says

    /// A new row: a cell of the list's, which the row shows.
    private func setUp(_ row: UnsafeMutableRawPointer?) {
        guard let row, !released else { return }
        let cell = GTKItemCell()
        cell.row = OpaquePointer(row)
        cell.across = shape.isAcross
        made[OpaquePointer(row)] = cell
        gtk_list_item_set_child(OpaquePointer(row), cell.widget)
    }

    /// The row shows the entry at its place: its cell holds it, a header or a footer neither chosen nor activated.
    private func bind(_ row: UnsafeMutableRawPointer?) {
        guard let row, !released, let cell = made[OpaquePointer(row)] else { return }
        let place = Int(gtk_list_item_get_position(OpaquePointer(row)))
        let identity = identity(at: guint(place))
        let isItem = cells.isItem(identity)
        gtk_list_item_set_selectable(OpaquePointer(row), isItem ? 1 : 0)
        gtk_list_item_set_activatable(OpaquePointer(row), isItem ? 1 : 0)
        cell.place = place
        cell.across = shape.isAcross
        if let placement, placement.rooms.indices.contains(place) { cell.keep(placement.rooms[place]) }
        binding += 1
        defer { binding -= 1 }
        cells.hold(identity, in: cell)
        tellShowing()
    }

    private func unbind(_ row: UnsafeMutableRawPointer?) {
        guard let row, !released, let cell = made[OpaquePointer(row)] else { return }
        cell.place = nil
        cells.endShowing(in: cell)
    }

    private func tearDown(_ row: UnsafeMutableRawPointer?) {
        guard let row else { return }
        made[OpaquePointer(row)] = nil
    }

    private func activated(_ place: Int) {
        guard !released else { return }
        cells.userActivated(identity(at: guint(place)))
    }

    /// Tells the tree every item chosen now.
    private func choiceChanged() {
        guard !released, let selection else { return }
        let chosen = gtk_selection_model_get_selection(selection)
        defer { gtk_bitset_unref(chosen) }
        let count = gtk_bitset_get_size(chosen)
        cells.userChose((0..<count).map { identity(at: gtk_bitset_get_nth(chosen, guint($0))) })
    }

    /// The entries in view, told once GTK has laid the list out: it binds rows far beside the view, and maps some
    /// beside it while it measures rows it has not yet.
    private func tellShowing() {
        guard !tellsShowing else { return }
        tellsShowing = true
        GTKDoorbell.afterLayout { [weak self] in
            guard let self else { return }
            tellsShowing = false
            guard !released, let list else { return }
            cells.showing(made.values.filter { Self.stands($0, inViewOf: list) }.compactMap(\.identity))
        }
    }

    /// Whether `cell` stands within the view of `list`, which is its own viewport.
    private static func stands(_ cell: GTKItemCell, inViewOf list: GTKWidget) -> Bool {
        var bounds = graphene_rect_t()
        guard gtk_widget_get_mapped(cell.widget) != 0, gtk_widget_compute_bounds(cell.widget, list, &bounds) != 0
        else { return false }
        let (width, height) = (Float(gtk_widget_get_width(list)), Float(gtk_widget_get_height(list)))
        return bounds.size.width > 0 && bounds.size.height > 0
            && bounds.origin.x < width && bounds.origin.x + bounds.size.width > 0
            && bounds.origin.y < height && bounds.origin.y + bounds.size.height > 0
    }

    /// The identity at `place` of the string list.
    func identity(at place: guint) -> String {
        gtk_string_list_get_string(model, place).map { String(cString: $0) } ?? ""
    }

    // MARK: - Acts

    /// Scrolls until the item of `identity` stands where `anchor` says: GTK brings it into view, and once it is laid
    /// out the scrolled window stands where the anchor says (`ScrollAnchor.place`).
    func scroll(to identity: String, anchor: ScrollAnchor) {
        guard let list, let place = cells.identities.firstIndex(of: identity) else { return }
        if case .grid = shape {
            gtk_grid_view_scroll_to(list.opaque, guint(place), GTK_LIST_SCROLL_NONE, nil)
        } else {
            gtk_list_view_scroll_to(list.opaque, guint(place), GTK_LIST_SCROLL_NONE, nil)
        }
        GTKDoorbell.afterLayout { [weak self] in self?.settle(identity, anchor: anchor) }
    }

    /// Stands the scrolled window for the item of `identity`, laid out, where `anchor` says.
    private func settle(_ identity: String, anchor: ScrollAnchor) {
        guard let list, let cell = cells.holding(of: identity) as? GTKItemCell else { return }
        var bounds = graphene_rect_t()
        guard gtk_widget_compute_bounds(cell.widget, list, &bounds) != 0 else { return }
        let across = shape.isAcross
        let scrolled = scroller.widget.opaque
        guard let adjustment = across
            ? gtk_scrolled_window_get_hadjustment(scrolled) : gtk_scrolled_window_get_vadjustment(scrolled)
        else { return }
        let now = gtk_adjustment_get_value(adjustment)
        let start = now + Double(across ? bounds.origin.x : bounds.origin.y)
        let length = Double(across ? bounds.size.width : bounds.size.height)
        guard let target = anchor.place(of: start, length: length, in: gtk_adjustment_get_page_size(adjustment), at: now)
        else { return }
        gtk_adjustment_set_value(adjustment, target)
    }

    /// The list left: its rows let their cells go, and they leave with it.
    override func detach() {
        super.detach()
        released = true
        waiting = []
        gtk_scrolled_window_set_child(scroller.widget.opaque, nil)
        list = nil
        selection = nil
        made = [:]
    }
}

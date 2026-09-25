// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A TabbedView: a `GtkStack` of its tabs, chosen by a `GtkStackSwitcher` - its tabs' captions joined in one
/// control - which stands in the middle of the header bar of the frame the tabbed view stands in.
/// Design: docs/design/platforms/gtk/pages.md#tabs
@MainActor
final class GTKTabbedView: GTKLayoutView {
    /// The tab the user sees; nil until the tree or the user chooses one.
    private(set) var selectedIndex: Int?

    /// What the view does when the user chooses a tab, handed the one it showed and the one it shows.
    var onSelection: ((_ previous: Int, _ selected: Int) -> Void)?

    /// The switcher its frame's header bar shows in its middle.
    let switcher = GTKWidgetView { gtk_stack_switcher_new() }

    private let stack = GTKWidgetView { gtk_stack_new() }
    private var tabs: [GTKView] = []
    private var titles: [String] = []

    override init() {
        super.init()
        stack.placingLayout = self
        setChildren([stack])
        gtk_stack_switcher_set_stack(switcher.widget.opaque, stack.widget.opaque)
        connectNotify(UnsafeMutableRawPointer(stack.widget), "visible-child", number: number) { _, _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKTabbedView)?.visibleChildMoved() }
        }
    }

    /// The tab the view shows, as an index into its tabs.
    var shownIndex: Int { selectedIndex ?? 0 }

    /// The tabs: each a view of the stack, named as its title.
    @discardableResult
    override func setItems(_ items: [GTKLayoutItem]) -> Bool {
        let views = items.map(\.view)
        guard views.count != tabs.count || !zip(views, tabs).allSatisfy({ $0 === $1 }) else { return false }

        ProgramWrite.perform {
            for gone in tabs where !views.contains(where: { $0 === gone }) {
                gtk_stack_remove(stack.widget.opaque, gone.widget)
            }
            for (index, view) in views.enumerated() where !tabs.contains(where: { $0 === view }) {
                view.placingLayout = nil
                gtk_stack_add_titled(stack.widget.opaque, view.widget, "tab\(view.number)", title(at: index))
            }
            tabs = views
            showSelected()
        }
        invalidateMeasurements()
        return true
    }

    /// Names the tabs and shows the one the tree asks for, where the user has not chosen another since.
    func show(_ titles: [String], requested: Int?) {
        self.titles = titles
        for (index, view) in tabs.enumerated() {
            guard let page = gtk_stack_get_page(stack.widget.opaque, view.widget) else { continue }
            gtk_stack_page_set_title(page, title(at: index))
        }
        if let requested, requested != selectedIndex {
            selectedIndex = requested
            ProgramWrite.perform { showSelected() }
        }
    }

    private func title(at index: Int) -> String {
        titles.indices.contains(index) ? titles[index] : ""
    }

    private func showSelected() {
        guard !tabs.isEmpty else { return }
        gtk_stack_set_visible_child(stack.widget.opaque, tabs[min(max(shownIndex, 0), tabs.count - 1)].widget)
    }

    /// The switcher showed another tab: the user chose it.
    private func visibleChildMoved() {
        guard !ProgramWrite.isWriting, let shown = gtk_stack_get_visible_child(stack.widget.opaque),
              let index = tabs.firstIndex(where: { $0.widget == shown }), index != shownIndex
        else { return }

        let previous = shownIndex
        selectedIndex = index
        onSelection?(previous, index)
    }

    /// Chooses a tab as the user's switcher does.
    func selectByUser(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        gtk_stack_set_visible_child(stack.widget.opaque, tabs[index].widget)
    }

    override func contentSize(width: Double?) -> LayoutSize {
        stack.measure(width: width, height: nil)
    }

    override func arrange(in bounds: Rect) {
        stack.layout(bounds)
    }

    override func detach() {
        super.detach()
        onSelection = nil
    }
}

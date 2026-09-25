// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A NavigationStack: libadwaita's `AdwNavigationView`, each page in a frame with its own header bar, pushed and
/// popped as the path changes - with GTK's slide, its back button, its swipe and its keys.
/// Design: docs/design/platforms/gtk/pages.md#a-navigation-stack
@MainActor
final class GTKNavigationView: GTKLayoutView {
    /// Says the user took the top page away, handed how many pages remain.
    var onPopped: ((Int) -> Void)?

    /// The pages the view holds, bottom first, each in its frame and its navigation page.
    private(set) var stack: [(frame: GTKPageFrame, page: GTKWidget)] = []

    private let navigation = GTKWidgetView { adw_navigation_view_new() }

    /// The pages' titles as the tree says them, in the pages' order - what a page pushed is named before its chrome
    /// is composed.
    var titles: [String] = []

    override init() {
        super.init()
        navigation.placingLayout = self
        setChildren([navigation])
        connectSignal(UnsafeMutableRawPointer(navigation.widget), "popped", number: number) { _, page, data in
            nonisolated(unsafe) let page = page
            MainActor.assumeIsolated {
                (GTKView.find(viewNumber(data)) as? GTKNavigationView)?.popped(page?.assumingMemoryBound(to: GtkWidget.self))
            }
        }
    }

    /// The frame of every page, bottom first.
    var frames: [GTKPageFrame] { stack.map(\.frame) }

    /// The pages: pushed where one joins the top, popped to where the path shortened, replaced otherwise - each as
    /// the program's move.
    @discardableResult
    override func setItems(_ items: [GTKLayoutItem]) -> Bool {
        let pages = items.map(\.view)
        guard pages.count != stack.count || !zip(pages, stack).allSatisfy({ $0 === $1.frame.page }) else { return false }
        for page in pages { page.placingLayout = nil }

        let kept = zip(pages, stack).prefix { $0 === $1.frame.page }.count
        ProgramWrite.perform {
            if kept == stack.count, pages.count == kept + 1 {
                stack.append(entry(for: pages[kept], at: kept))
                adw_navigation_view_push(navigation.widget.opaque, stack[kept].page.of(AdwNavigationPage.self))
            } else if kept == pages.count, kept > 0 {
                adw_navigation_view_pop_to_page(navigation.widget.opaque, stack[kept - 1].page.of(AdwNavigationPage.self))
                stack.removeLast(stack.count - kept)
            } else {
                let previous = stack
                stack = pages.enumerated().map { index, page in
                    previous.first { $0.frame.page === page } ?? entry(for: page, at: index)
                }
                var natives = stack.map { Optional($0.page.of(AdwNavigationPage.self)) }
                adw_navigation_view_replace(navigation.widget.opaque, &natives, Int32(natives.count))
            }
        }
        invalidateMeasurements()
        return true
    }

    /// A page in a frame, in a navigation page of its own, named as the tree names it or, until it does, after the
    /// application - libadwaita asks every page for a title.
    private func entry(for page: GTKView, at index: Int) -> (frame: GTKPageFrame, page: GTKWidget) {
        let frame = GTKPageFrame(page: page)
        let given = titles.indices.contains(index) ? titles[index] : ""
        let title = given.isEmpty ? g_get_application_name().map { String(cString: $0) } ?? " " : given
        let native = adw_navigation_page_new(frame.widget, title)!.of(GtkWidget.self)
        g_object_ref_sink(native)
        return (frame, native)
    }

    /// Names a page, for its header bar and for assistive technology, and says whether the user may take it away.
    func describe(_ frame: GTKPageFrame, title: String, canPop: Bool) {
        guard let native = stack.first(where: { $0.frame === frame })?.page else { return }
        adw_navigation_page_set_title(native.of(AdwNavigationPage.self), title)
        adw_navigation_page_set_can_pop(native.of(AdwNavigationPage.self), canPop ? 1 : 0)
    }

    /// A page left the view: the program's pop is its write's echo; the user's - the back button, the swipe, the
    /// keys - says how many remain.
    private func popped(_ page: GTKWidget?) {
        guard !ProgramWrite.isWriting, let index = stack.firstIndex(where: { $0.page == page }) else { return }
        stack.removeLast(stack.count - index)
        onPopped?(stack.count)
    }

    /// Takes the top page away as the user's back does; whether there was one below it.
    func popByUser() -> Bool {
        adw_navigation_view_pop(navigation.widget.opaque) != 0
    }

    override func contentSize(width: Double?) -> LayoutSize {
        navigation.measure(width: width, height: nil)
    }

    override func arrange(in bounds: Rect) {
        navigation.layout(bounds)
    }

    override func detach() {
        super.detach()
        onPopped = nil
    }

    isolated deinit {
        for entry in stack { g_object_unref(entry.page) }
    }
}

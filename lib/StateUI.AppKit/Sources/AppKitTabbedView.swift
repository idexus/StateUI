// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// One page offered by a native AppKit tab bar.
@MainActor
struct AppKitTabItem {
    let layout: AppKitLayoutItem
    let title: String?
    let image: NSImage?
}

/// AppKit's presentation of a tabbed view: a native `NSTabView` over the
/// pages StateUI owns.
///
/// Where the window serves the tabbed view, the tab view shows no tabs and no
/// border, and the row of tabs beneath the window's toolbar chooses; anywhere
/// else its tabs stand on the top edge of its content, as a Mac tab view's do.
/// The tab view is the system's, and nothing is painted on it.
@MainActor
final class AppKitTabbedView: AppKitHitTestView, AppKitWidthConstrainedMeasuring,
    NSTabViewDelegate {
    var onSelection: ((_ previous: Int, _ selected: Int) -> Void)?

    /// Whether the window shows this tabbed view's tabs, beneath its toolbar.
    /// The tab view then shows no tabs and no border, and the page takes the
    /// whole view.
    var tabsShownByWindow = false {
        didSet {
            guard tabsShownByWindow != oldValue else { return }
            tabView.tabViewType = tabsShownByWindow ? .noTabsNoBorder : .topTabsBezelBorder
            invalidateIntrinsicContentSize()
            needsLayout = true
        }
    }

    private let tabView = NSTabView()
    private var items: [AppKitTabItem] = []
    private(set) var selectedIndex = -1

    /// Set while this side selects, so the tab view's report of it is not
    /// taken for the user's.
    private var selecting = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        tabView.tabViewType = .topTabsBezelBorder
        tabView.delegate = self
        addSubview(tabView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitTabbedView is created in code")
    }

    override var isFlipped: Bool { true }

    /// Reconciles the native tabs and returns a platform fallback only when
    /// the selected page itself disappeared from the arrangement.
    func setItems(_ items: [AppKitTabItem], requestedIndex: Int?) -> Int? {
        // THE TABS IT HAS, CHOSEN AS THEY ARE: a patch on its way to a page
        // applies this view again, and that asks nothing of it.
        if Self.sameTabs(self.items, items), requestedIndex.map({ $0 == selectedIndex }) ?? true {
            return nil
        }

        let formerView = item(at: selectedIndex)?.layout.view
        let formerIndex = selectedIndex
        self.items = items
        reconcileTabs()

        let next: Int
        var fallback: Int?
        if let requestedIndex, items.indices.contains(requestedIndex) {
            next = requestedIndex
        } else if let formerView,
                  let preserved = items.firstIndex(where: { $0.layout.view === formerView }) {
            next = preserved
        } else if items.isEmpty {
            next = -1
        } else {
            next = 0
            if formerIndex >= 0 { fallback = next }
        }

        show(next)
        return fallback
    }

    /// Whether two runs of tabs show the same pages the same way.
    private static func sameTabs(_ left: [AppKitTabItem], _ right: [AppKitTabItem]) -> Bool {
        left.count == right.count && zip(left, right).allSatisfy {
            $0.layout.arranges(like: $1.layout) && $0.title == $1.title && $0.image === $1.image
        }
    }

    /// Selects a tab as the user does from the window's row of tabs. A tab the
    /// user clicks on the tab view itself arrives through its delegate.
    func selectByUser(_ next: Int) {
        guard items.indices.contains(next), next != selectedIndex else { return }
        let previous = selectedIndex
        show(next)
        onSelection?(previous, next)
    }

    /// What each tab shows in a selector: its title and its picture.
    var segments: [(title: String, image: NSImage?)] {
        items.map { ($0.title ?? "", $0.image) }
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard !selecting, let tabViewItem else { return }
        let next = tabView.indexOfTabViewItem(tabViewItem)
        guard items.indices.contains(next), next != selectedIndex else { return }
        let previous = selectedIndex
        selectedIndex = next
        invalidateIntrinsicContentSize()
        needsLayout = true
        onSelection?(previous, next)
    }

    override var intrinsicContentSize: NSSize {
        fittingContentSize(width: nil)
    }

    /// The chosen page's size, measured by the page for the width inside the
    /// tab view's own frame, and that frame around it.
    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        let chrome = Self.chrome(of: tabView.tabViewType)
        let minimum = tabView.minimumSize.width
        guard let item = item(at: selectedIndex) else {
            return NSSize(width: minimum, height: chrome.top + chrome.bottom)
        }

        let size = item.layout.fittingSize(
            width: availableWidth.map { max(0, $0 - chrome.left - chrome.right) })
        let margin = item.layout.margin
        return NSSize(
            width: max(minimum,
                size.width + margin.left + margin.right + chrome.left + chrome.right),
            height: size.height + margin.top + margin.bottom + chrome.top + chrome.bottom)
    }

    override func layout() {
        super.layout()
        tabView.frame = bounds
        tabView.selectedTabViewItem?.view?.frame = tabView.contentRect
    }

    /// One native tab per page, each holding its page in a pane, labelled by
    /// the segments.
    private func reconcileTabs() {
        selecting = true
        defer { selecting = false }

        let standing = tabView.tabViewItems.map { ($0.view as? AppKitTabPane)?.item?.view }
        let same = standing.count == items.count
            && zip(standing, items).allSatisfy { $0 === $1.layout.view }

        if !same {
            for tab in tabView.tabViewItems.reversed() {
                tabView.removeTabViewItem(tab)
            }
            for _ in items {
                let tab = NSTabViewItem(identifier: nil)
                tab.view = AppKitTabPane()
                tabView.addTabViewItem(tab)
            }
        }

        for (index, segment) in segments.enumerated() {
            let tab = tabView.tabViewItems[index]
            (tab.view as? AppKitTabPane)?.item = items[index].layout
            tab.label = segment.title
            tab.image = segment.image
        }
    }

    private func show(_ index: Int) {
        selectedIndex = index
        if tabView.tabViewItems.indices.contains(index) {
            let wasSelecting = selecting
            selecting = true
            tabView.selectTabViewItem(at: index)
            selecting = wasSelecting
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    /// The room a tab view of a kind takes around its page, measured once on
    /// a probe large enough to hold it.
    private static var chromes: [NSTabView.TabType: NSEdgeInsets] = [:]

    private static func chrome(of type: NSTabView.TabType) -> NSEdgeInsets {
        if let known = chromes[type] { return known }

        let probe = NSTabView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        probe.tabViewType = type
        probe.addTabViewItem(NSTabViewItem(identifier: nil))
        let content = probe.contentRect
        let bounds = probe.bounds
        let chrome = NSEdgeInsets(
            top: probe.isFlipped ? content.minY - bounds.minY : bounds.maxY - content.maxY,
            left: content.minX - bounds.minX,
            bottom: probe.isFlipped ? bounds.maxY - content.maxY : content.minY - bounds.minY,
            right: bounds.maxX - content.maxX)
        chromes[type] = chrome
        return chrome
    }

    /// Clicks a tab on the tab view, as the user does.
    func selectForTesting(_ index: Int) {
        tabView.selectTabViewItem(at: index)
    }

    var selectedIndexForTesting: Int { selectedIndex }
    var showsTabsForTesting: Bool { tabView.tabViewType != .noTabsNoBorder }
    var tabLabelsForTesting: [String] { tabView.tabViewItems.map(\.label) }

    private func item(at index: Int) -> AppKitTabItem? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }
}

/// A tab's page inside the native tab view, laid at its margins.
@MainActor
final class AppKitTabPane: NSView {
    var item: AppKitLayoutItem? {
        didSet {
            guard !AppKitLayoutItem.sameArrangement(oldValue, item) else { return }
            if let view = item?.view, view.superview !== self {
                addSubview(view)
            }
            needsLayout = true
        }
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        guard let item else { return }
        let margin = item.margin
        item.view.frame = NSRect(
            x: margin.left,
            y: margin.top,
            width: max(0, bounds.width - margin.left - margin.right),
            height: max(0, bounds.height - margin.top - margin.bottom))
    }
}

#endif

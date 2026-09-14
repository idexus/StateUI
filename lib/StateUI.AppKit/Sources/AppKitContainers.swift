// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import QuartzCore
@_spi(Host) import StateUI

/// Native StateUI containers measure their descendants against the width the
/// parent actually offers. AppKit's unconstrained `fittingSize` cannot carry
/// that proposal through frame-based containers, so wrapped native text would
/// otherwise grow only after its ancestors had already chosen their heights.
@MainActor
protocol AppKitWidthConstrainedMeasuring: AnyObject {
    func fittingContentSize(width: CGFloat?) -> NSSize
}

/// The sizes one native view measured, by the width its parent offered.
///
/// A size is kept until something that can change it happens: the view's own
/// content or arrangement, or a descendant's. `invalidateMeasurements()` is the
/// one road by which such a change forgets it, from the changed view up to its
/// window, so an unchanged subtree beside the change is never measured again.
@MainActor
final class AppKitMeasurementCache {
    private var sizes: [(width: CGFloat?, size: NSSize)] = []

    /// The size measured for `width`, measuring only when none is kept.
    func size(offering width: CGFloat?, measure: () -> NSSize) -> NSSize {
        if let kept = sizes.first(where: { $0.width == width }) { return kept.size }

        let measured = measure()
        if sizes.count == Self.capacity { sizes.removeFirst() }
        sizes.append((width, measured))
        return measured
    }

    /// Forgets every kept size.
    func invalidate() {
        sizes.removeAll(keepingCapacity: true)
    }

    /// A parent offers a view one or two widths in a pass: its natural width
    /// and the width it then lays the view out in.
    private static let capacity = 4
}

/// A StateUI container or text surface that keeps its own measurements.
@MainActor
protocol AppKitMeasurementCaching: AnyObject {
    var measurements: AppKitMeasurementCache { get }
}

@MainActor
extension NSView {
    /// Forgets the measurement of this view and of every ancestor up to the
    /// window's content view, and asks each of them to lay out again. A change
    /// that cannot alter a size never calls this, so nothing beside it moves.
    func invalidateMeasurements() {
        var current: NSView? = self

        while let view = current {
            (view as? AppKitMeasurementCaching)?.measurements.invalidate()
            view.invalidateIntrinsicContentSize()
            view.needsLayout = true
            if view === view.window?.contentView { break }
            current = view.superview
        }
    }
}

/// Layout information owned by the StateUI child rather than its AppKit view.
@MainActor
struct AppKitLayoutItem {
    let view: NSView
    var margin = NSEdgeInsets()
    var horizontal: Int32 = 3
    var vertical: Int32 = 3
    var width: CGFloat?
    var height: CGFloat?
    var minimumWidth: CGFloat?
    var minimumHeight: CGFloat?
    var maximumWidth: CGFloat?
    var maximumHeight: CGFloat?
    var row = 0
    var column = 0
    var rowSpan = 1
    var columnSpan = 1
    var absoluteBounds: [Double]?
    var absoluteProportions: Int32 = 0

    /// How the view is drawn over its frame, for a layout that places it.
    var drawing: AppKitViewDrawing?

    func fittingSize(width availableWidth: CGFloat? = nil) -> NSSize {
        if let measurable = view as? AppKitWidthConstrainedMeasuring {
            let available = availableWidth.map {
                max(0, $0 - margin.left - margin.right)
            }
            let measured = measurable.fittingContentSize(width: available)
            return NSSize(
                width: boundedWidth(width ?? measured.width),
                height: boundedHeight(height ?? measured.height))
        }

        if let label = view as? NSTextField, let availableWidth, availableWidth.isFinite {
            label.preferredMaxLayoutWidth = max(0, availableWidth - margin.left - margin.right)
        }

        let measured = view.fittingSize
        return NSSize(
            width: boundedWidth(width ?? measured.width),
            height: boundedHeight(height ?? measured.height))
    }

    func boundedWidth(_ proposed: CGFloat, available: CGFloat? = nil) -> CGFloat {
        appKitBoundedExtent(
            proposed,
            minimum: minimumWidth,
            maximum: maximumWidth,
            available: available)
    }

    func boundedHeight(_ proposed: CGFloat, available: CGFloat? = nil) -> CGFloat {
        appKitBoundedExtent(
            proposed,
            minimum: minimumHeight,
            maximum: maximumHeight,
            available: available)
    }

    /// Whether a parent would place this item exactly as it places `other`:
    /// the same native view with the same layout values.
    func arranges(like other: AppKitLayoutItem) -> Bool {
        view === other.view
            && NSEdgeInsetsEqual(margin, other.margin)
            && horizontal == other.horizontal
            && vertical == other.vertical
            && width == other.width
            && height == other.height
            && minimumWidth == other.minimumWidth
            && minimumHeight == other.minimumHeight
            && maximumWidth == other.maximumWidth
            && maximumHeight == other.maximumHeight
            && row == other.row
            && column == other.column
            && rowSpan == other.rowSpan
            && columnSpan == other.columnSpan
            && absoluteBounds == other.absoluteBounds
            && absoluteProportions == other.absoluteProportions
    }

    /// Whether two complete arrangements place the same views the same way.
    static func sameArrangement(
        _ left: [AppKitLayoutItem],
        _ right: [AppKitLayoutItem]
    ) -> Bool {
        left.count == right.count && zip(left, right).allSatisfy { $0.arranges(like: $1) }
    }

    /// Whether two optional single-child arrangements are the same.
    static func sameArrangement(_ left: AppKitLayoutItem?, _ right: AppKitLayoutItem?) -> Bool {
        switch (left, right) {
        case (nil, nil): true
        case let (left?, right?): left.arranges(like: right)
        default: false
        }
    }
}

/// A StateUI-owned AppKit surface with the library's hit-testing semantics.
///
/// AppKit finds the deepest native view through `hitTest(_:)`. A transparent
/// layout either removes its complete subtree from that search or, when
/// cascading is disabled, removes only itself and keeps interactive children.
///
/// An element that answers a tap is also pressed by assistive technology: its
/// `pressAction` runs the same handler a click runs, so VoiceOver and
/// automation reach it through the native accessibility press.
@MainActor
class AppKitHitTestView: NSView {
    private var ignoresInput = false
    private var transparencyReachesChildren = true

    /// What an accessibility press performs, while the element answers a tap.
    var pressAction: (() -> Void)?

    override func accessibilityPerformPress() -> Bool {
        guard let pressAction else { return false }
        pressAction()
        return true
    }

    func applyInputTransparency(_ transparent: Bool, cascades: Bool) {
        ignoresInput = transparent
        transparencyReachesChildren = cascades
    }

    var inputTransparencyForTesting: (transparent: Bool, cascades: Bool) {
        (ignoresInput, transparencyReachesChildren)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard ignoresInput else { return super.hitTest(point) }
        guard !transparencyReachesChildren else { return nil }

        let target = super.hitTest(point)
        return target === self ? nil : target
    }
}

/// A native canvas for children with authored or engine-driven placement.
@MainActor
final class AppKitAbsoluteLayoutView: AppKitHitTestView {
    var placement: HostPlacementRun? {
        didSet { needsLayout = true }
    }
    private var items: [AppKitLayoutItem] = []
    private var retainedViews: [ObjectIdentifier] = []
    private var drawingOrder: [ObjectIdentifier] = []

    override var isFlipped: Bool { true }

    func setItems(
        _ items: [AppKitLayoutItem],
        retaining retained: [AppKitLayoutItem] = [],
        preservesSubviewOrder: Bool = false
    ) {
        let retainedViews = retained.map { ObjectIdentifier($0.view) }
        guard !AppKitLayoutItem.sameArrangement(self.items, items)
            || retainedViews != self.retainedViews
        else { return }

        self.retainedViews = retainedViews
        let all = items + retained

        if preservesSubviewOrder {
            let wanted = Set(all.map { ObjectIdentifier($0.view) })
            for child in subviews where !wanted.contains(ObjectIdentifier(child)) {
                child.removeFromSuperview()
            }
            for item in all where item.view.superview !== self {
                item.view.translatesAutoresizingMaskIntoConstraints = true
                addSubview(item.view)
            }
        } else {
            replaceSubviews(with: all.map(\.view))
        }

        self.items = items
        drawingOrder = []
        invalidateMeasurements()
    }

    override var intrinsicContentSize: NSSize {
        var width: CGFloat = 0
        var height: CGFloat = 0

        for item in items where !item.view.isHidden {
            let natural = item.fittingSize()
            let bounds = item.absoluteBounds ?? [0, 0, -1, -1]
            let childWidth = bounds.count > 2 && bounds[2] >= 0 ? bounds[2] : natural.width
            let childHeight = bounds.count > 3 && bounds[3] >= 0 ? bounds[3] : natural.height
            width = max(width, (bounds.first ?? 0) + childWidth)
            height = max(height, (bounds.count > 1 ? bounds[1] : 0) + childHeight)
        }

        return NSSize(width: width, height: height)
    }

    override func layout() {
        super.layout()

        if let placements = placement?.placements, !placements.isEmpty {
            apply(placements)
            return
        }

        for item in items { drawUnplaced(item) }
        for item in items where !item.view.isHidden {
            let values = item.absoluteBounds ?? [0, 0, -1, -1]
            let natural = item.fittingSize()
            let flags = item.absoluteProportions
            var width = values.count > 2 ? CGFloat(values[2]) : natural.width
            var height = values.count > 3 ? CGFloat(values[3]) : natural.height

            if width < 0 { width = natural.width }
            if height < 0 { height = natural.height }
            if flags & 4 != 0 { width *= bounds.width }
            if flags & 8 != 0 { height *= bounds.height }
            width = item.boundedWidth(width)
            height = item.boundedHeight(height)

            var x = CGFloat(values.first ?? 0)
            var y = CGFloat(values.count > 1 ? values[1] : 0)
            if flags & 1 != 0 { x *= max(0, bounds.width - width) }
            if flags & 2 != 0 { y *= max(0, bounds.height - height) }

            item.view.frame = NSRect(x: x, y: y, width: width, height: height)
        }
    }

    private func apply(_ placements: [HostPlacement]) {
        let count = min(items.count, placements.count)
        let ordered = (0..<count).sorted {
            placements[$0].zIndex == placements[$1].zIndex
                ? $0 < $1
                : placements[$0].zIndex < placements[$1].zIndex
        }
        let identities = ordered.map { ObjectIdentifier(items[$0].view) }

        if identities != drawingOrder {
            for index in ordered {
                let child = items[index].view
                child.removeFromSuperview()
                addSubview(child)
            }
            drawingOrder = identities
        }

        for index in 0..<count {
            let placement = placements[index]
            let item = items[index]
            item.view.frame = NSRect(
                x: placement.bounds.x,
                y: placement.bounds.y,
                width: max(0, placement.bounds.width),
                height: max(0, placement.bounds.height))
            (item.view as? AppKitGridView)?.setShadeOpacity(placement.shade)
            item.drawing?.placement = placement.drawing
            item.drawing?.placedOpacity = min(max(placement.opacity, 0), 1)
        }
        for item in items[count...] { drawUnplaced(item) }
    }

    /// A child the run places nothing for is drawn by its own values alone.
    private func drawUnplaced(_ item: AppKitLayoutItem) {
        item.drawing?.placement = nil
        item.drawing?.placedOpacity = 1
    }
}

/// A deterministic frame-based stack shared by horizontal and vertical stacks.
@MainActor
final class AppKitStackView: AppKitHitTestView, AppKitWidthConstrainedMeasuring,
    AppKitMeasurementCaching {
    enum Axis {
        case horizontal
        case vertical
    }

    let axis: Axis
    let measurements = AppKitMeasurementCache()
    var spacing: CGFloat = 0 {
        didSet { if spacing != oldValue { invalidateMeasurements() } }
    }
    var padding = NSEdgeInsets() {
        didSet { if !NSEdgeInsetsEqual(padding, oldValue) { invalidateMeasurements() } }
    }
    private(set) var items: [AppKitLayoutItem] = []
    private(set) var arrangementCountForTesting = 0

    init(axis: Axis) {
        self.axis = axis
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitStackView is created in code")
    }

    override var isFlipped: Bool { true }

    func setItems(_ items: [AppKitLayoutItem]) {
        arrangementCountForTesting += 1
        guard !AppKitLayoutItem.sameArrangement(self.items, items) else { return }

        replaceSubviews(with: items.map(\.view))
        self.items = items
        invalidateMeasurements()
    }

    override var intrinsicContentSize: NSSize {
        fittingContentSize(width: nil)
    }

    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        measurements.size(offering: availableWidth) {
            measuredContentSize(width: availableWidth)
        }
    }

    /// Measures each visible child once for the width this stack offers it.
    private func measuredContentSize(width availableWidth: CGFloat?) -> NSSize {
        let visible = items.filter { !$0.view.isHidden }
        let gaps = spacing * CGFloat(max(visible.count - 1, 0))
        var along: CGFloat = 0
        var across: CGFloat = 0

        switch axis {
        case .vertical:
            let childWidth = availableWidth.map {
                max(0, $0 - padding.left - padding.right)
            }
            for item in visible {
                let size = item.fittingSize(width: childWidth)
                along += size.height + item.margin.top + item.margin.bottom
                across = max(across, size.width + item.margin.left + item.margin.right)
            }
            return NSSize(
                width: padding.left + padding.right + across,
                height: padding.top + padding.bottom + gaps + along)

        case .horizontal:
            for item in visible {
                let size = item.fittingSize()
                along += size.width + item.margin.left + item.margin.right
                across = max(across, size.height + item.margin.top + item.margin.bottom)
            }
            return NSSize(
                width: padding.left + padding.right + gaps + along,
                height: padding.top + padding.bottom + across)
        }
    }

    override func layout() {
        super.layout()

        let content = bounds.inset(by: padding)
        var offset: CGFloat = axis == .vertical ? content.minY : content.minX

        for item in items where !item.view.isHidden {
            let cross = axis == .vertical ? content.width : content.height
            let natural = item.fittingSize(width: axis == .vertical ? cross : nil)

            switch axis {
            case .vertical:
                offset += item.margin.top
                let width = extent(
                    option: item.horizontal,
                    explicit: item.width,
                    natural: natural.width,
                    available: max(0, content.width - item.margin.left - item.margin.right),
                    minimum: item.minimumWidth,
                    maximum: item.maximumWidth)
                let x = position(
                    option: item.horizontal,
                    extent: width,
                    start: content.minX + item.margin.left,
                    available: max(0, content.width - item.margin.left - item.margin.right))
                let height = item.boundedHeight(natural.height)
                item.view.frame = NSRect(x: x, y: offset, width: width, height: height)
                offset += height + item.margin.bottom + spacing

            case .horizontal:
                offset += item.margin.left
                let height = extent(
                    option: item.vertical,
                    explicit: item.height,
                    natural: natural.height,
                    available: max(0, content.height - item.margin.top - item.margin.bottom),
                    minimum: item.minimumHeight,
                    maximum: item.maximumHeight)
                let y = position(
                    option: item.vertical,
                    extent: height,
                    start: content.minY + item.margin.top,
                    available: max(0, content.height - item.margin.top - item.margin.bottom))
                let width = item.boundedWidth(natural.width)
                item.view.frame = NSRect(x: offset, y: y, width: width, height: height)
                offset += width + item.margin.right + spacing
            }
        }
    }
}

/// A one-child native container used by pages and content-bearing controls.
@MainActor
class AppKitSingleChildView: AppKitHitTestView, AppKitWidthConstrainedMeasuring,
    AppKitMeasurementCaching {
    let measurements = AppKitMeasurementCache()
    var padding = NSEdgeInsets() {
        didSet { if !NSEdgeInsetsEqual(padding, oldValue) { invalidateMeasurements() } }
    }

    /// Whether the child keeps out of the part of this view that the window's
    /// title bar and toolbar cover.
    var insetsBySafeArea = false {
        didSet { if insetsBySafeArea != oldValue { needsLayout = true } }
    }
    private(set) var item: AppKitLayoutItem?

    override var isFlipped: Bool { true }

    func setItem(_ item: AppKitLayoutItem?) {
        guard !AppKitLayoutItem.sameArrangement(self.item, item) else { return }

        replaceSubviews(with: item.map { [$0.view] } ?? [])
        self.item = item
        invalidateMeasurements()
    }

    override var intrinsicContentSize: NSSize {
        fittingContentSize(width: nil)
    }

    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        measurements.size(offering: availableWidth) {
            measuredContentSize(width: availableWidth)
        }
    }

    private func measuredContentSize(width availableWidth: CGFloat?) -> NSSize {
        guard let item, !item.view.isHidden else {
            return NSSize(width: padding.left + padding.right, height: padding.top + padding.bottom)
        }

        let contentWidth = availableWidth.map {
            max(0, $0 - padding.left - padding.right)
        }
        let size = item.fittingSize(width: contentWidth)
        return NSSize(
            width: padding.left + padding.right + item.margin.left + item.margin.right + size.width,
            height: padding.top + padding.bottom + item.margin.top + item.margin.bottom + size.height)
    }

    override func layout() {
        super.layout()
        guard let item, !item.view.isHidden else { return }

        let content = (insetsBySafeArea ? safeAreaRect : bounds).inset(by: padding)
        let availableWidth = max(0, content.width - item.margin.left - item.margin.right)
        let availableHeight = max(0, content.height - item.margin.top - item.margin.bottom)
        let natural = item.fittingSize(width: availableWidth)
        let width = extent(
            option: item.horizontal,
            explicit: item.width,
            natural: natural.width,
            available: availableWidth,
            minimum: item.minimumWidth,
            maximum: item.maximumWidth)
        let height = extent(
            option: item.vertical,
            explicit: item.height,
            natural: natural.height,
            available: availableHeight,
            minimum: item.minimumHeight,
            maximum: item.maximumHeight)

        item.view.frame = NSRect(
            x: position(
                option: item.horizontal,
                extent: width,
                start: content.minX + item.margin.left,
                available: availableWidth),
            y: position(
                option: item.vertical,
                extent: height,
                start: content.minY + item.margin.top,
                available: availableHeight),
            width: width,
            height: height)
    }
}

/// The stable native root of one StateUI window. Pages and overlays occupy
/// AppKit's safe content rectangle, leaving native title and toolbar areas to
/// the window; a split page spans the whole window, under them, and keeps its
/// panes' pages out of them itself. A window overlay is a slot, not a second
/// page: it is composed above the page and transparent to input wherever its
/// child has no hit target.
@MainActor
final class AppKitWindowContentView: NSView {
    private weak var page: NSView?
    private var pageSpansTitleBar = false
    private let overlaySurface = AppKitOverlaySurfaceView()

    /// The colour the window's bars are written in, painted over `barBand`.
    /// Nil leaves the title bar and toolbar the system's material.
    var barColor: NSColor? {
        didSet { if barColor != oldValue { needsDisplay = true } }
    }

    /// The part of the window the title bar and toolbar cover.
    var barBand: NSRect {
        NSRect(x: 0, y: 0, width: bounds.width, height: max(0, safeAreaRect.minY))
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let barColor else { return }
        barColor.setFill()
        barBand.fill()
    }

    func set(page: NSView?, overlay: AppKitLayoutItem?, spansTitleBar: Bool = false) {
        if pageSpansTitleBar != spansTitleBar {
            pageSpansTitleBar = spansTitleBar
            needsLayout = true
        }
        if self.page !== page {
            self.page?.removeFromSuperview()
            self.page = page
            if let page {
                page.translatesAutoresizingMaskIntoConstraints = true
                addSubview(page, positioned: .below, relativeTo: nil)
            }
        }

        overlaySurface.setItem(overlay)
        if overlay == nil {
            overlaySurface.removeFromSuperview()
        } else if overlaySurface.superview !== self {
            addSubview(overlaySurface, positioned: .above, relativeTo: page)
        }

        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        page?.fittingSize ?? .zero
    }

    override func layout() {
        super.layout()
        page?.frame = pageSpansTitleBar ? bounds : safeAreaRect
        overlaySurface.frame = safeAreaRect
        overlaySurface.layoutSubtreeIfNeeded()
        if barColor != nil { needsDisplay = true }
    }
}

/// One pane of a split view. Its page keeps out of the part the window's title
/// bar and toolbar cover, and a colour written for the bars paints that part.
@MainActor
final class AppKitPaneView: AppKitSingleChildView {
    /// The colour the window's bars are written in, painted over `barBand`.
    var barColor: NSColor? {
        didSet { if barColor != oldValue { needsDisplay = true } }
    }

    /// The part of this pane the window's title bar and toolbar cover.
    var barBand: NSRect {
        NSRect(x: 0, y: 0, width: bounds.width, height: max(0, safeAreaRect.minY))
    }

    override func layout() {
        super.layout()
        if barColor != nil { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let barColor else { return }
        barColor.setFill()
        barBand.fill()
    }
}

/// Full-window hit-test surface whose empty area deliberately falls through
/// to the page below it.
@MainActor
private final class AppKitOverlaySurfaceView: AppKitSingleChildView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let target = super.hitTest(point)
        return target === self ? nil : target
    }
}

/// AppKit's presentation of the stack whose identity stays in Swift.
///
/// Every page view remains owned by its `MountedNode`; this view shows only
/// the top one, across its whole frame. The stack's furniture - the top
/// page's title, the way back and the page's actions - is the window's
/// toolbar, which the window controller composes from the visible
/// arrangement, so AppKit is given no second navigation model to reconcile
/// with StateUI's path.
@MainActor
final class AppKitNavigationView: AppKitHitTestView {
    private var items: [AppKitLayoutItem] = []

    override var isFlipped: Bool { true }

    func setItems(_ items: [AppKitLayoutItem]) {
        guard !AppKitLayoutItem.sameArrangement(self.items, items) else { return }

        let previous = self.items.last?.view
        let next = items.last?.view
        self.items = items

        if previous !== next {
            previous?.removeFromSuperview()
            if let next { addSubview(next) }
        }

        invalidateMeasurements()
    }

    override var intrinsicContentSize: NSSize {
        guard let item = items.last else { return .zero }
        let size = item.fittingSize()
        return NSSize(
            width: size.width + item.margin.left + item.margin.right,
            height: size.height + item.margin.top + item.margin.bottom)
    }

    override func layout() {
        super.layout()
        guard let item = items.last else { return }

        let margin = item.margin
        item.view.frame = NSRect(
            x: margin.left,
            y: margin.top,
            width: max(0, bounds.width - margin.left - margin.right),
            height: max(0, bounds.height - margin.top - margin.bottom))
    }

    var topViewForTesting: NSView? { items.last?.view }
}

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
final class AppKitTabbedView: AppKitHitTestView, NSTabViewDelegate {
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
    /// taken for the reader's.
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

    /// Selects a tab as the reader does from the window's row of tabs. A tab the
    /// reader clicks on the tab view itself arrives through its delegate.
    func selectByReader(_ next: Int) {
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
        let chrome = Self.chrome(of: tabView.tabViewType)
        let minimum = tabView.minimumSize.width
        guard let item = item(at: selectedIndex) else {
            return NSSize(width: minimum, height: chrome.top + chrome.bottom)
        }

        let size = item.layout.fittingSize()
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

    /// Clicks a tab on the tab view, as the reader does.
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

/// AppKit's presentation of a split view: the sidebar page in a native
/// sidebar, the detail page beside it.
///
/// The split view spans the whole window, under the title bar and toolbar, so
/// the sidebar runs the window's full height as a Mac sidebar does; each pane
/// keeps its page out of the part the title bar covers. The window's toolbar
/// carries the system sidebar toggle and a separator that tracks the divider.
/// Whether the sidebar shows is StateUI's binding. The host's one adaptation
/// is that a window wide enough for both panes opens with it shown; after
/// that, the reader and the application decide.
@MainActor
final class AppKitSplitView: AppKitHitTestView {
    var onPresentationChanged: ((Bool) -> Void)?

    /// The native split view controller the window's toolbar toggles.
    let splitController = NSSplitViewController()

    /// The width at which a window opens with both panes shown.
    private static let sidebarRoom: CGFloat = 720

    private let sidebarController = NSViewController()
    private let detailController = NSViewController()
    private let sidebarSurface = AppKitPaneView()
    private let detailSurface = AppKitPaneView()
    private lazy var sidebarItem = NSSplitViewItem(
        sidebarWithViewController: sidebarController)
    private lazy var detailItem = NSSplitViewItem(
        viewController: detailController)
    private var requestedPresentation = false
    private var applyingPresentation = false
    private var lastEffectivePresentation = false
    private var adapted = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        sidebarSurface.insetsBySafeArea = true
        detailSurface.insetsBySafeArea = true
        sidebarController.view = sidebarSurface
        detailController.view = detailSurface
        sidebarItem.canCollapse = true
        sidebarItem.allowsFullHeightLayout = true
        sidebarItem.minimumThickness = 260
        sidebarItem.maximumThickness = 340
        splitController.addSplitViewItem(sidebarItem)
        splitController.addSplitViewItem(detailItem)
        splitController.splitView.isVertical = true
        splitController.splitView.dividerStyle = .thin
        splitController.splitView.translatesAutoresizingMaskIntoConstraints = true
        splitController.splitView.autoresizingMask = [.width, .height]
        splitController.view.translatesAutoresizingMaskIntoConstraints = true
        addSubview(splitController.view)

        applyingPresentation = true
        sidebarItem.isCollapsed = true
        applyingPresentation = false
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(splitViewResized(_:)),
            name: NSSplitView.didResizeSubviewsNotification,
            object: splitController.splitView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitSplitView is created in code")
    }

    override var isFlipped: Bool { true }

    /// Shows a row across the top of the detail - the tabs of a tabbed view
    /// standing in it - as the detail item's own accessory, or takes it away.
    @available(macOS 26, *)
    func setDetailRow(_ row: NSView?) {
        let standing = detailItem.topAlignedAccessoryViewControllers.first?.view
        guard standing !== row else { return }

        if !detailItem.topAlignedAccessoryViewControllers.isEmpty {
            detailItem.removeTopAlignedAccessoryViewController(at: 0)
        }
        if let row {
            let accessory = NSSplitViewItemAccessoryViewController()
            accessory.view = row
            // The row stands over the page rather than on a band of its own:
            // a soft edge lets the page show beneath the tabs.
            if #available(macOS 26.1, *) { accessory.preferredScrollEdgeEffectStyle = .soft }
            detailItem.addTopAlignedAccessoryViewController(accessory)
        }
    }

    /// Paints the part of the detail the window's bars cover in the colour
    /// written for them, or leaves it to the system's material.
    func setDetailBarColor(_ color: NSColor?) {
        detailSurface.barColor = color
    }

    var detailBarColorForTesting: NSColor? { detailSurface.barColor }
    var sidebarBarColorForTesting: NSColor? { sidebarSurface.barColor }

    @available(macOS 26, *)
    var detailRowForTesting: NSView? {
        detailItem.topAlignedAccessoryViewControllers.first?.view
    }

    @available(macOS 26, *)
    var detailRowAccessoryForTesting: NSSplitViewItemAccessoryViewController? {
        detailItem.topAlignedAccessoryViewControllers.first
    }

    func setItems(_ items: [AppKitLayoutItem]) {
        sidebarSurface.setItem(items.first)
        detailSurface.setItem(items.count > 1 ? items[1] : nil)
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    /// Applies Swift's value without echoing it back as a reader's change.
    func apply(presented: Bool) {
        requestedPresentation = presented
        setSidebarPresented(presented, reporting: false)
    }

    override var intrinsicContentSize: NSSize {
        let sidebar = sidebarSurface.intrinsicContentSize
        let detail = detailSurface.intrinsicContentSize
        let divider = splitController.splitView.dividerThickness
        return NSSize(
            width: max(detail.width, sidebar.width + divider + detail.width),
            height: max(sidebar.height, detail.height))
    }

    override func layout() {
        super.layout()
        splitController.view.frame = bounds
        adaptToFirstRoom()
        splitController.view.layoutSubtreeIfNeeded()

        // A detached NSSplitViewController has no parent view controller to
        // constrain its split view. AppKit otherwise keeps the panes at their
        // fitting height, allowing a tall document to escape above this host
        // surface. The native split view owns pane layout within these bounds.
        splitController.splitView.frame = splitController.view.bounds
        splitController.splitView.needsLayout = true
        splitController.splitView.layoutSubtreeIfNeeded()
    }

    /// The host's one adaptation: a window wide enough for both panes opens
    /// with its sidebar shown, and reports it to the binding.
    private func adaptToFirstRoom() {
        guard !adapted, bounds.width > 0 else { return }
        adapted = true
        guard !requestedPresentation, bounds.width >= Self.sidebarRoom else { return }

        requestedPresentation = true
        setSidebarPresented(true, reporting: true)
    }

    private func setSidebarPresented(_ presented: Bool, reporting: Bool) {
        let previous = !sidebarItem.isCollapsed
        guard previous != presented else {
            lastEffectivePresentation = presented
            return
        }

        applyingPresentation = true
        sidebarItem.isCollapsed = !presented
        applyingPresentation = false
        lastEffectivePresentation = presented

        if reporting {
            onPresentationChanged?(presented)
        }
    }

    @objc private func splitViewResized(_ notification: Notification) {
        guard !applyingPresentation else { return }
        let presented = !sidebarItem.isCollapsed
        guard presented != lastEffectivePresentation else { return }

        requestedPresentation = presented
        lastEffectivePresentation = presented
        onPresentationChanged?(presented)
    }

    var isEffectivelyPresented: Bool { !sidebarItem.isCollapsed }
    var isEffectivelyPresentedForTesting: Bool { isEffectivelyPresented }
    var sidebarWidthForTesting: CGFloat {
        splitController.splitView.subviews.first?.frame.width ?? 0
    }

    /// What the reader's sidebar toggle leaves behind, without its animation.
    func toggleForTesting() {
        sidebarItem.isCollapsed.toggle()
    }
}

/// One parsed row or column definition in a StateUI grid.
struct AppKitGridLength: Equatable {
    enum Kind {
        case fixed
        case proportional
        case auto
    }

    let kind: Kind
    let value: CGFloat

    init(kind: Kind, value: CGFloat) {
        self.kind = kind
        self.value = value
    }

    init?(_ value: HostValue) {
        guard let parts = value.values,
              let rawKind = parts.first?.enumeration,
              let amount = parts.value(1)?.number
        else { return nil }

        switch rawKind {
        case 0: kind = .fixed
        case 1: kind = .proportional
        case 2: kind = .auto
        default: return nil
        }

        self.value = max(0, amount)
    }
}

/// AppKit's deterministic implementation of StateUI's row-and-column layout.
@MainActor
final class AppKitGridView: AppKitHitTestView {
    var rows: [AppKitGridLength] = [] {
        didSet { if rows != oldValue { invalidateMeasurements() } }
    }
    var columns: [AppKitGridLength] = [] {
        didSet { if columns != oldValue { invalidateMeasurements() } }
    }
    var rowSpacing: CGFloat = 0 {
        didSet { if rowSpacing != oldValue { invalidateMeasurements() } }
    }
    var columnSpacing: CGFloat = 0 {
        didSet { if columnSpacing != oldValue { invalidateMeasurements() } }
    }
    var padding = NSEdgeInsets() {
        didSet { if !NSEdgeInsetsEqual(padding, oldValue) { invalidateMeasurements() } }
    }
    private var items: [AppKitLayoutItem] = []

    override var isFlipped: Bool { true }

    func setItems(_ items: [AppKitLayoutItem]) {
        guard !AppKitLayoutItem.sameArrangement(self.items, items) else { return }

        replaceSubviews(with: items.map(\.view))
        self.items = items
        invalidateMeasurements()
    }

    /// Applies a placed layout's shade to its guaranteed second child.
    func setShadeOpacity(_ opacity: Double) {
        guard items.count > 1 else { return }
        items[1].view.alphaValue = min(max(opacity, 0), 1)
    }

    override var intrinsicContentSize: NSSize {
        let rowCount = max(rows.count, (items.map { $0.row + $0.rowSpan }.max() ?? 1))
        let columnCount = max(columns.count, (items.map { $0.column + $0.columnSpan }.max() ?? 1))
        let measuredRows = trackSizes(
            definitions: completed(rows, count: rowCount),
            count: rowCount,
            available: nil,
            spacing: rowSpacing,
            vertical: true)
        let measuredColumns = trackSizes(
            definitions: completed(columns, count: columnCount),
            count: columnCount,
            available: nil,
            spacing: columnSpacing,
            vertical: false)

        return NSSize(
            width: padding.left + padding.right + measuredColumns.reduce(0, +)
                + columnSpacing * CGFloat(max(columnCount - 1, 0)),
            height: padding.top + padding.bottom + measuredRows.reduce(0, +)
                + rowSpacing * CGFloat(max(rowCount - 1, 0)))
    }

    override func layout() {
        super.layout()

        let content = bounds.inset(by: padding)
        let rowCount = max(rows.count, (items.map { $0.row + $0.rowSpan }.max() ?? 1))
        let columnCount = max(columns.count, (items.map { $0.column + $0.columnSpan }.max() ?? 1))
        let rowDefinitions = completed(rows, count: rowCount)
        let columnDefinitions = completed(columns, count: columnCount)
        let rowSizes = trackSizes(
            definitions: rowDefinitions,
            count: rowCount,
            available: content.height,
            spacing: rowSpacing,
            vertical: true)
        let columnSizes = trackSizes(
            definitions: columnDefinitions,
            count: columnCount,
            available: content.width,
            spacing: columnSpacing,
            vertical: false)
        let rowOrigins = origins(of: rowSizes, start: content.minY, spacing: rowSpacing)
        let columnOrigins = origins(of: columnSizes, start: content.minX, spacing: columnSpacing)

        for item in items where !item.view.isHidden {
            let row = min(max(item.row, 0), rowCount - 1)
            let column = min(max(item.column, 0), columnCount - 1)
            let rowEnd = min(row + max(item.rowSpan, 1), rowCount)
            let columnEnd = min(column + max(item.columnSpan, 1), columnCount)
            let cellWidth = columnSizes[column..<columnEnd].reduce(0, +)
                + columnSpacing * CGFloat(max(columnEnd - column - 1, 0))
            let cellHeight = rowSizes[row..<rowEnd].reduce(0, +)
                + rowSpacing * CGFloat(max(rowEnd - row - 1, 0))
            let availableWidth = max(0, cellWidth - item.margin.left - item.margin.right)
            let availableHeight = max(0, cellHeight - item.margin.top - item.margin.bottom)
            let natural = item.fittingSize(width: availableWidth)
            let width = extent(
                option: item.horizontal,
                explicit: item.width,
                natural: natural.width,
                available: availableWidth,
                minimum: item.minimumWidth,
                maximum: item.maximumWidth)
            let height = extent(
                option: item.vertical,
                explicit: item.height,
                natural: natural.height,
                available: availableHeight,
                minimum: item.minimumHeight,
                maximum: item.maximumHeight)

            item.view.frame = NSRect(
                x: position(
                    option: item.horizontal,
                    extent: width,
                    start: columnOrigins[column] + item.margin.left,
                    available: availableWidth),
                y: position(
                    option: item.vertical,
                    extent: height,
                    start: rowOrigins[row] + item.margin.top,
                    available: availableHeight),
                width: width,
                height: height)
        }
    }

    private func completed(_ definitions: [AppKitGridLength], count: Int) -> [AppKitGridLength] {
        definitions + Array(
            repeating: AppKitGridLength(kind: .proportional, value: 1),
            count: max(0, count - definitions.count))
    }

    private func trackSizes(
        definitions: [AppKitGridLength],
        count: Int,
        available: CGFloat?,
        spacing: CGFloat,
        vertical: Bool
    ) -> [CGFloat] {
        var sizes = Array(repeating: CGFloat(0), count: count)

        for index in 0..<count where definitions[index].kind == .fixed {
            sizes[index] = definitions[index].value
        }

        for item in items where !item.view.isHidden {
            let track = vertical ? item.row : item.column
            let span = vertical ? item.rowSpan : item.columnSpan
            guard span == 1, track >= 0, track < count, definitions[track].kind == .auto else {
                continue
            }

            let measured = item.fittingSize()
            let extent = vertical
                ? measured.height + item.margin.top + item.margin.bottom
                : measured.width + item.margin.left + item.margin.right
            sizes[track] = max(sizes[track], extent)
        }

        let gaps = spacing * CGFloat(max(count - 1, 0))
        let fixed = sizes.reduce(0, +) + gaps
        let starWeight = definitions.reduce(CGFloat(0)) {
            $0 + ($1.kind == .proportional ? max($1.value, 0.000_001) : 0)
        }
        let remainder = max(0, (available ?? fixed) - fixed)

        for index in 0..<count where definitions[index].kind == .proportional {
            if available == nil {
                let matching = items.filter {
                    (vertical ? $0.row : $0.column) == index
                        && (vertical ? $0.rowSpan : $0.columnSpan) == 1
                        && !$0.view.isHidden
                }
                sizes[index] = matching.map {
                    let measured = $0.fittingSize()
                    return vertical
                        ? measured.height + $0.margin.top + $0.margin.bottom
                        : measured.width + $0.margin.left + $0.margin.right
                }.max() ?? 0
            } else {
                sizes[index] = remainder * max(definitions[index].value, 0.000_001) / starWeight
            }
        }

        return sizes
    }

    private func origins(of sizes: [CGFloat], start: CGFloat, spacing: CGFloat) -> [CGFloat] {
        var answer: [CGFloat] = []
        var cursor = start

        for size in sizes {
            answer.append(cursor)
            cursor += size + spacing
        }

        return answer
    }
}

/// A native scroll surface whose document geometry and settling rules are
/// shared by ordinary scrollers and arithmetic scroll readers.
@MainActor
final class AppKitScrollView: NSScrollView, AppKitWidthConstrainedMeasuring {
    var onOffsetChanged: ((NSPoint, NSPoint) -> Void)?
    var onSnapItemChanged: ((Int) -> Void)?
    var onScrollStopped: (() -> Void)?

    private(set) var orientation = ScrollOrientation.vertical
    private(set) var padding = NSEdgeInsets()
    private var verticalBarVisibility: Int32 = 0
    private var horizontalBarVisibility: Int32 = 0
    private var snapInterval: CGFloat = 0
    private var snapFrom: CGFloat = 0
    private var momentum: CGFloat = 1
    private var snapsAtMost = 0

    private let documentSurface = AppKitScrollDocumentView()
    private let stackWrapper = AppKitStackView(axis: .vertical)
    private var usesStackWrapper = false
    private var applyingOffset = false
    private var pendingOffset: NSPoint?
    private var lastObservedOffset = NSPoint.zero
    private var movementStart = NSPoint.zero
    private var movementActive = false
    private var movementChanged = false
    private var liveScrolling = false
    private var settling = false
    private var discreteWheelMovement = false
    private var gestureScroller: WheelScroller?
    private var lastSnapItem: Int?
    private var stopWorkItem: DispatchWorkItem?

    var offset: NSPoint { reachable(contentView.bounds.origin) }
    var usesStackWrapperForTesting: Bool { usesStackWrapper }
    var documentChildCountForTesting: Int {
        usesStackWrapper ? stackWrapper.items.count : (documentSurface.item == nil ? 0 : 1)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        borderType = .noBorder
        scrollerStyle = .overlay
        contentView.postsBoundsChangedNotifications = true
        documentView = documentSurface

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipBoundsChanged(_:)),
            name: NSView.boundsDidChangeNotification,
            object: contentView)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willStartLiveScroll(_:)),
            name: NSScrollView.willStartLiveScrollNotification,
            object: self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEndLiveScroll(_:)),
            name: NSScrollView.didEndLiveScrollNotification,
            object: self)
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitScrollView is created in code")
    }

    func setItems(_ items: [AppKitLayoutItem]) {
        if items.count > 1 { usesStackWrapper = true }

        if usesStackWrapper {
            stackWrapper.setItems(items)
            documentSurface.item = AppKitLayoutItem(view: stackWrapper)
        } else {
            documentSurface.item = items.first
        }
    }

    func apply(
        orientation: Int32,
        padding: NSEdgeInsets,
        verticalBarVisibility: Int32,
        horizontalBarVisibility: Int32,
        offset: NSPoint?,
        snapInterval: Double,
        snapFrom: Double,
        momentum: Double,
        snapsAtMost: Int
    ) {
        let normalizedOrientation = ScrollOrientation(rawValue: orientation) ?? .vertical
        if self.orientation != normalizedOrientation
            || self.snapInterval != max(0, CGFloat(snapInterval))
            || self.snapFrom != CGFloat(snapFrom.isFinite ? snapFrom : 0) {
            lastSnapItem = nil
        }
        self.orientation = normalizedOrientation
        self.padding = padding
        self.verticalBarVisibility = verticalBarVisibility
        self.horizontalBarVisibility = horizontalBarVisibility
        self.snapInterval = CGFloat(max(0, snapInterval))
        self.snapFrom = CGFloat(snapFrom.isFinite ? snapFrom : 0)
        self.momentum = CGFloat(max(0, momentum.isFinite ? momentum : 1))
        self.snapsAtMost = max(0, snapsAtMost)
        documentSurface.padding = padding
        documentSurface.orientation = self.orientation

        let allowsHorizontal = self.orientation == .horizontal || self.orientation == .both
        let allowsVertical = self.orientation == .vertical || self.orientation == .both
        hasHorizontalScroller = allowsHorizontal && horizontalBarVisibility != 2
        hasVerticalScroller = allowsVertical && verticalBarVisibility != 2
        autohidesScrollers = verticalBarVisibility != 1 && horizontalBarVisibility != 1

        if self.orientation == .neither {
            pendingOffset = .zero
        } else if let offset, offset.x.isFinite, offset.y.isFinite {
            pendingOffset = offset
            if documentSurface.frame.width > 0, documentSurface.frame.height > 0 {
                move(to: offset, asReader: false)
                pendingOffset = nil
            }
        }
        if pendingOffset != nil { needsLayout = true }
    }

    override var intrinsicContentSize: NSSize {
        fittingContentSize(width: nil)
    }

    /// The document's natural extent before the parent chooses a viewport.
    /// The scrolling axis may then be clipped, while the other axis keeps the
    /// measured size needed by rows such as a tab strip or a code block.
    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        documentSurface.fittingContentSize(width: availableWidth)
    }

    override func layout() {
        super.layout()
        documentSurface.arrange(in: contentSize)
        super.layout()

        if let pendingOffset {
            self.pendingOffset = nil
            move(to: pendingOffset, asReader: false)
        } else {
            move(to: contentView.bounds.origin, asReader: false)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if wheelScroller(for: event) == .enclosing,
            let enclosingScroller = enclosingScrollView {
            discreteWheelMovement = false
            enclosingScroller.scrollWheel(with: event)
            return
        }

        guard !event.hasPreciseScrollingDeltas, snapInterval > 0 else {
            discreteWheelMovement = false
            super.scrollWheel(with: event)
            return
        }

        let horizontal = -event.scrollingDeltaX
        let vertical = -event.scrollingDeltaY
        let delta: CGFloat = switch orientation {
        case .horizontal: abs(horizontal) > 0.000_001 ? horizontal : vertical
        case .vertical: vertical
        case .both: abs(horizontal) >= abs(vertical) ? horizontal : vertical
        case .neither: 0
        }

        if !stepDiscreteWheel(by: delta) {
            super.scrollWheel(with: event)
        }
    }

    private enum WheelScroller { case own, enclosing }

    /// A one-axis viewport owns gestures along that axis. A dominant gesture
    /// along its disabled axis belongs to the nearest enclosing viewport, so a
    /// horizontal strip does not interrupt its vertical page.
    ///
    /// A wheel click decides alone. A trackpad gesture is decided once, by
    /// its first moving event, and keeps that viewport through its end and
    /// its momentum, which carry no direction of their own: the viewport that
    /// sees a gesture begin is the one that sees it end and settles.
    private func wheelScroller(for event: NSEvent) -> WheelScroller {
        guard !event.phase.isEmpty || !event.momentumPhase.isEmpty else {
            gestureScroller = nil
            return scroller(followingDirectionOf: event) ?? .own
        }
        if event.phase.contains(.mayBegin) || event.phase.contains(.began) {
            gestureScroller = nil
        }
        if gestureScroller == nil {
            gestureScroller = scroller(followingDirectionOf: event)
        }
        return gestureScroller ?? .own
    }

    private func scroller(followingDirectionOf event: NSEvent) -> WheelScroller? {
        if orientation == .neither { return .enclosing }
        let horizontal = abs(event.scrollingDeltaX)
        let vertical = abs(event.scrollingDeltaY)
        guard max(horizontal, vertical) > 0.000_001 else { return nil }

        let handsOver = switch orientation {
        case .horizontal:
            !event.modifierFlags.contains(.shift) && vertical > horizontal
        case .vertical:
            horizontal > vertical
        case .both, .neither:
            false
        }
        return handsOver ? .enclosing : .own
    }

    @objc private func willStartLiveScroll(_ notification: Notification) {
        liveScrolling = true
        discreteWheelMovement = false
        beginMovement()
    }

    @objc private func didEndLiveScroll(_ notification: Notification) {
        liveScrolling = false
        settle(animated: true)
    }

    @objc private func clipBoundsChanged(_ notification: Notification) {
        guard !applyingOffset else { return }
        let current = offset
        guard current != lastObservedOffset else { return }
        if !movementActive { beginMovement() }
        readerMoved(from: lastObservedOffset, to: current)
        lastObservedOffset = current
        if !liveScrolling && !settling { scheduleRest() }
    }

    private func beginMovement() {
        stopWorkItem?.cancel()
        movementStart = offset
        movementActive = true
        movementChanged = false
    }

    /// A coarse wheel is a discrete command, not a short drag. On a snap grid
    /// it therefore advances to the next point even when the native line delta
    /// is smaller than half the interval. Precise devices remain entirely in
    /// AppKit's native scrolling path.
    private func stepDiscreteWheel(by direction: CGFloat) -> Bool {
        guard snapInterval > 0, orientation != .neither,
              direction.isFinite, abs(direction) > 0.000_001 else {
            return false
        }

        let current = offset
        let horizontal = orientation != .vertical
        let standing = horizontal ? current.x : current.y
        let destination = CGFloat(HostScrollMath.steppedGridDestination(
            from: Double(standing),
            direction: Double(direction),
            interval: Double(snapInterval),
            origin: Double(snapFrom)))
        var target = current
        if horizontal { target.x = destination } else { target.y = destination }
        target = reachable(target)
        guard target != current else { return false }

        if !movementActive { beginMovement() }
        movementStart = current
        discreteWheelMovement = true
        move(to: target, asReader: true)
        return true
    }

    private func readerMoved(from old: NSPoint, to new: NSPoint) {
        guard old != new else { return }
        movementChanged = true
        onOffsetChanged?(old, new)
        reportSnapItem(at: new)
    }

    private func move(to requested: NSPoint, asReader: Bool) {
        let old = offset
        let target = reachable(normalized(requested))
        applyingOffset = true
        contentView.scroll(to: target)
        reflectScrolledClipView(contentView)
        applyingOffset = false
        let current = offset
        lastObservedOffset = current

        if asReader {
            readerMoved(from: old, to: current)
            if !liveScrolling && !settling { scheduleRest() }
        }
    }

    private func scheduleRest() {
        stopWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.settle(animated: true) }
        stopWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func settle(animated: Bool) {
        stopWorkItem?.cancel()
        stopWorkItem = nil
        guard movementActive else { return }

        if discreteWheelMovement {
            finishMovement()
            return
        }

        let current = offset
        var target = current
        let horizontal = orientation != .vertical
        let start = horizontal ? movementStart.x : movementStart.y
        let present = horizontal ? current.x : current.y
        var destination = CGFloat(HostScrollMath.projectedDestination(
            start: Double(start),
            nativeDestination: Double(present),
            momentum: Double(momentum)))

        if snapInterval > 0 {
            destination = CGFloat(HostScrollMath.snapPoint(
                Double(destination),
                interval: Double(snapInterval),
                from: Double(snapFrom)))
            destination = CGFloat(HostScrollMath.heldDestination(
                Double(destination),
                movementStart: Double(start),
                interval: Double(snapInterval),
                from: Double(snapFrom),
                atMost: snapsAtMost))
        }

        if horizontal { target.x = destination } else { target.y = destination }
        target = reachable(target)
        let shouldAnimate = animated && target != current

        if shouldAnimate {
            settling = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                contentView.animator().setBoundsOrigin(target)
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.settling = false
                    self.finishMovement()
                }
            }
        } else {
            move(to: target, asReader: true)
            finishMovement()
        }
    }

    private func finishMovement() {
        guard movementActive else { return }
        movementActive = false
        if movementChanged { onScrollStopped?() }
        movementChanged = false
        discreteWheelMovement = false
    }

    private func reportSnapItem(at point: NSPoint) {
        guard snapInterval > 0 else { return }
        let value = orientation == .vertical ? point.y : point.x
        let item = HostScrollMath.nearestItem(
            Double(value), interval: Double(snapInterval), from: Double(snapFrom))
        guard item != lastSnapItem else { return }
        lastSnapItem = item
        onSnapItemChanged?(item)
    }

    private func normalized(_ point: NSPoint) -> NSPoint {
        switch orientation {
        case .horizontal: return NSPoint(x: point.x, y: 0)
        case .vertical: return NSPoint(x: 0, y: point.y)
        case .both: return point
        case .neither: return .zero
        }
    }

    private func reachable(_ point: NSPoint) -> NSPoint {
        let documentSize = documentSurface.frame.size
        return NSPoint(
            x: CGFloat(HostScrollMath.reachable(
                Double(point.x),
                content: Double(documentSize.width),
                viewport: Double(contentSize.width))),
            y: CGFloat(HostScrollMath.reachable(
                Double(point.y),
                content: Double(documentSize.height),
                viewport: Double(contentSize.height))))
    }

    func beginMovementForTesting() {
        beginMovement()
    }

    func moveAsReaderForTesting(to point: NSPoint) {
        move(to: point, asReader: true)
    }

    func settleForTesting() {
        settle(animated: false)
    }

    func stepDiscreteWheelForTesting(by direction: CGFloat) -> Bool {
        stepDiscreteWheel(by: direction)
    }
}

@MainActor
private final class AppKitScrollDocumentView: NSView, AppKitMeasurementCaching {
    let measurements = AppKitMeasurementCache()
    var item: AppKitLayoutItem? {
        didSet {
            guard !AppKitLayoutItem.sameArrangement(oldValue, item) else { return }
            replaceSubviews(with: item.map { [$0.view] } ?? [])
            invalidateMeasurements()
        }
    }
    var padding = NSEdgeInsets() {
        didSet { if !NSEdgeInsetsEqual(padding, oldValue) { invalidateMeasurements() } }
    }
    var orientation = ScrollOrientation.vertical {
        didSet { if orientation != oldValue { invalidateMeasurements() } }
    }

    override var isFlipped: Bool { true }

    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        measurements.size(offering: availableWidth) {
            measuredContentSize(width: availableWidth)
        }
    }

    private func measuredContentSize(width availableWidth: CGFloat?) -> NSSize {
        guard let item else { return .zero }

        let horizontalInsets = padding.left + padding.right + item.margin.left + item.margin.right
        let verticalInsets = padding.top + padding.bottom + item.margin.top + item.margin.bottom
        let constrainedWidth: CGFloat? = orientation == .vertical || orientation == .neither
            ? availableWidth.map { max(0, $0 - horizontalInsets) }
            : nil
        let natural = item.fittingSize(width: constrainedWidth)
        let contentWidth = item.horizontal == 3 && item.width == nil
            ? (constrainedWidth ?? natural.width)
            : natural.width

        return NSSize(
            width: max(0, contentWidth + horizontalInsets),
            height: max(0, natural.height + verticalInsets))
    }

    func arrange(in viewport: NSSize) {
        guard let item else {
            frame.size = viewport
            return
        }

        let horizontalInsets = padding.left + padding.right + item.margin.left + item.margin.right
        let verticalInsets = padding.top + padding.bottom + item.margin.top + item.margin.bottom
        let constrainedWidth: CGFloat? = orientation == .vertical || orientation == .neither
            ? max(0, viewport.width - horizontalInsets)
            : nil
        let natural = item.fittingSize(width: constrainedWidth)
        let documentWidth: CGFloat = switch orientation {
        case .horizontal, .both: max(viewport.width, natural.width + horizontalInsets)
        case .vertical, .neither: viewport.width
        }
        let documentHeight: CGFloat = switch orientation {
        case .vertical, .both: max(viewport.height, natural.height + verticalInsets)
        case .horizontal, .neither: viewport.height
        }
        frame = NSRect(origin: .zero, size: NSSize(width: documentWidth, height: documentHeight))

        let room = NSRect(
            x: padding.left + item.margin.left,
            y: padding.top + item.margin.top,
            width: max(0, documentWidth - horizontalInsets),
            height: max(0, documentHeight - verticalInsets))
        let width = extent(
            option: item.horizontal,
            explicit: item.width,
            natural: natural.width,
            available: room.width,
            minimum: item.minimumWidth,
            maximum: item.maximumWidth)
        let height = extent(
            option: item.vertical,
            explicit: item.height,
            natural: natural.height,
            available: room.height,
            minimum: item.minimumHeight,
            maximum: item.maximumHeight)
        item.view.frame = NSRect(
            x: position(option: item.horizontal, extent: width, start: room.minX, available: room.width),
            y: position(option: item.vertical, extent: height, start: room.minY, available: room.height),
            width: max(0, width),
            height: max(0, height))
        item.view.needsLayout = true
    }
}

/// A border that clips its background and outline to the requested shape.
@MainActor
final class AppKitBorderView: AppKitSingleChildView {
    private var fill = AppKitBrush()
    private var stroke = AppKitBrush()
    private var strokeWidth: CGFloat = 1
    private var shape = AppKitBorderShape.rectangle

    func apply(
        backgroundColor: NSColor?,
        background: HostValue?,
        stroke: HostValue?,
        strokeWidth: Double?,
        shape: HostValue?
    ) {
        fill = AppKitBrush(background) ?? AppKitBrush(color: backgroundColor)
        self.stroke = AppKitBrush(stroke) ?? AppKitBrush()
        self.strokeWidth = max(0, strokeWidth ?? 1)
        self.shape = AppKitBorderShape(shape)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let inset = strokeWidth / 2
        let path = shape.path(in: bounds.insetBy(dx: inset, dy: inset))
        fill.draw(in: path, bounds: bounds)

        guard strokeWidth > 0 else { return }
        stroke.stroke(path, width: strokeWidth)
    }
}

private enum AppKitBorderShape {
    case rectangle
    case rounded(CGFloat)
    case ellipse

    init(_ value: HostValue?) {
        guard let parts = value?.values, let kind = parts.first?.enumeration else {
            self = .rectangle
            return
        }

        switch kind {
        case 1: self = .rounded(max(0, parts.value(1)?.number ?? 0))
        case 2: self = .ellipse
        default: self = .rectangle
        }
    }

    func path(in rect: NSRect) -> NSBezierPath {
        switch self {
        case .rectangle: return NSBezierPath(rect: rect)
        case .rounded(let radius):
            return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        case .ellipse: return NSBezierPath(ovalIn: rect)
        }
    }
}

struct AppKitBrush {
    enum Kind {
        case none
        case solid(NSColor)
        case linear([NSColor], [CGFloat], [Double])
        case radial([NSColor], [CGFloat], [Double])
    }

    var kind = Kind.none

    init() {}

    init(color: NSColor?) {
        kind = color.map(Kind.solid) ?? .none
    }

    init?(_ value: HostValue?) {
        guard let parts = value?.values, let rawKind = parts.first?.enumeration else { return nil }

        if rawKind == 1, let color = parts.value(1).flatMap(nsColor) {
            kind = .solid(color)
            return
        }

        guard rawKind == 2 || rawKind == 3,
              let geometry = parts.value(1)?.numbers
        else { return nil }

        var colors: [NSColor] = []
        var locations: [CGFloat] = []
        var index = 2

        while index + 1 < parts.count,
              let location = parts[index].number,
              let color = nsColor(parts[index + 1]) {
            locations.append(min(max(location, 0), 1))
            colors.append(color)
            index += 2
        }

        guard !colors.isEmpty else { return nil }
        kind = rawKind == 2
            ? .linear(colors, locations, geometry)
            : .radial(colors, locations, geometry)
    }

    func draw(in path: NSBezierPath, bounds: NSRect) {
        switch kind {
        case .none:
            return
        case .solid(let color):
            color.setFill()
            path.fill()
        case .linear(let colors, let locations, let geometry):
            guard geometry.count >= 4,
                  let gradient = NSGradient(
                    colors: colors,
                    atLocations: locations,
                    colorSpace: .deviceRGB)
            else { return }
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            gradient.draw(
                from: NSPoint(
                    x: bounds.minX + bounds.width * geometry[0],
                    y: bounds.minY + bounds.height * geometry[1]),
                to: NSPoint(
                    x: bounds.minX + bounds.width * geometry[2],
                    y: bounds.minY + bounds.height * geometry[3]),
                options: [])
            NSGraphicsContext.restoreGraphicsState()
        case .radial(let colors, let locations, let geometry):
            guard geometry.count >= 3,
                  let gradient = NSGradient(
                    colors: colors,
                    atLocations: locations,
                    colorSpace: .deviceRGB)
            else { return }
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            let center = NSPoint(
                x: bounds.minX + bounds.width * geometry[0],
                y: bounds.minY + bounds.height * geometry[1])
            gradient.draw(
                fromCenter: center,
                radius: 0,
                toCenter: center,
                radius: max(bounds.width, bounds.height) * geometry[2],
                options: [])
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    func stroke(_ path: NSBezierPath, width: CGFloat) {
        guard case .solid(let color) = kind else { return }
        color.setStroke()
        path.lineWidth = width
        path.stroke()
    }
}

/// A StateUI colour is four sRGB channels, drawn in sRGB exactly.
func nsColor(_ value: HostValue) -> NSColor? {
    guard let color = value.color else { return nil }
    return NSColor(
        srgbRed: CGFloat(color.red) / 255,
        green: CGFloat(color.green) / 255,
        blue: CGFloat(color.blue) / 255,
        alpha: CGFloat(color.alpha) / 255)
}

func appKitBoundedExtent(
    _ proposed: CGFloat,
    minimum: CGFloat?,
    maximum: CGFloat?,
    available: CGFloat? = nil
) -> CGFloat {
    let lower = max(0, minimum ?? 0)
    // A contradictory maximum cannot make the constraints unsatisfiable.
    // StateUI deterministically gives the authored minimum precedence.
    let upper = max(lower, maximum ?? .greatestFiniteMagnitude)
    let finite = proposed.isFinite ? proposed : lower
    var result = min(max(0, finite), upper)
    result = max(result, lower)
    if let available, available.isFinite {
        result = min(result, max(0, available))
    }
    return result
}

/// A child's extent along one axis of its slot. An explicit size wins over
/// every alignment and is bounded only by its own minimum and maximum;
/// without one, a filling child takes the slot and any other its natural size.
private func extent(
    option: Int32,
    explicit: CGFloat?,
    natural: CGFloat,
    available: CGFloat,
    minimum: CGFloat? = nil,
    maximum: CGFloat? = nil
) -> CGFloat {
    appKitBoundedExtent(
        explicit ?? (option == 3 ? available : natural),
        minimum: minimum,
        maximum: maximum,
        available: available)
}

/// Where a child of the given extent starts in its slot. A filling child
/// that stops short of the slot - an explicit size, or a maximum - stands in
/// the middle of it.
private func position(option: Int32, extent: CGFloat, start: CGFloat, available: CGFloat) -> CGFloat {
    switch option {
    case 1, 3: return start + max(0, available - extent) / 2
    case 2: return start + max(0, available - extent)
    default: return start
    }
}

private extension NSRect {
    func inset(by insets: NSEdgeInsets) -> NSRect {
        NSRect(
            x: origin.x + insets.left,
            y: origin.y + insets.top,
            width: max(0, width - insets.left - insets.right),
            height: max(0, height - insets.top - insets.bottom))
    }
}

@MainActor
private extension NSView {
    func replaceSubviews(with wanted: [NSView]) {
        let alreadyArranged = subviews.count == wanted.count
            && zip(subviews, wanted).allSatisfy { $0 === $1 }
        guard !alreadyArranged else { return }

        for child in subviews {
            child.removeFromSuperview()
        }

        for child in wanted {
            child.translatesAutoresizingMaskIntoConstraints = true
            addSubview(child)
        }
    }
}

#endif

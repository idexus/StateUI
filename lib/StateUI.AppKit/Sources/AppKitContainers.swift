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
    var absoluteFlags: Int32 = 0

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
}

/// A StateUI-owned AppKit surface with the library's hit-testing semantics.
///
/// AppKit finds the deepest native view through `hitTest(_:)`. A transparent
/// layout either removes its complete subtree from that search or, when
/// cascading is disabled, removes only itself and keeps interactive children.
@MainActor
class AppKitHitTestView: NSView {
    private var inputTransparent = false
    private var cascadeInputTransparent = true

    func applyInputTransparency(_ transparent: Bool, cascades: Bool) {
        inputTransparent = transparent
        cascadeInputTransparent = cascades
    }

    var inputTransparencyForTesting: (transparent: Bool, cascades: Bool) {
        (inputTransparent, cascadeInputTransparent)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard inputTransparent else { return super.hitTest(point) }
        guard !cascadeInputTransparent else { return nil }

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
    private var drawingOrder: [ObjectIdentifier] = []

    override var isFlipped: Bool { true }

    func setItems(
        _ items: [AppKitLayoutItem],
        retaining retained: [AppKitLayoutItem] = [],
        preservesSubviewOrder: Bool = false
    ) {
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
        invalidateIntrinsicContentSize()
        needsLayout = true
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

        for item in items where !item.view.isHidden {
            let values = item.absoluteBounds ?? [0, 0, -1, -1]
            let natural = item.fittingSize()
            let flags = item.absoluteFlags
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
            let child = items[index].view
            child.frame = NSRect(
                x: placement.bounds.x,
                y: placement.bounds.y,
                width: max(0, placement.bounds.width),
                height: max(0, placement.bounds.height))
            child.alphaValue = min(max(placement.opacity, 0), 1)
            (child as? AppKitGridView)?.setShadeOpacity(placement.shade)
            child.wantsLayer = true

            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(
                x: placement.translationX,
                y: placement.translationY)
            transform = transform.rotated(by: placement.rotation * .pi / 180)
            transform = transform.scaledBy(
                x: placement.scaleX,
                y: placement.scaleY)
            child.layer?.setAffineTransform(transform)
        }
    }
}

/// A deterministic frame-based stack shared by horizontal and vertical stacks.
@MainActor
final class AppKitStackView: AppKitHitTestView, AppKitWidthConstrainedMeasuring {
    enum Axis {
        case horizontal
        case vertical
    }

    let axis: Axis
    var spacing: CGFloat = 0 {
        didSet { invalidateIntrinsicContentSize(); needsLayout = true }
    }
    var padding = NSEdgeInsets() {
        didSet { invalidateIntrinsicContentSize(); needsLayout = true }
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
        replaceSubviews(with: items.map(\.view))
        self.items = items
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        fittingContentSize(width: nil)
    }

    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        let visible = items.filter { !$0.view.isHidden }
        let gaps = spacing * CGFloat(max(visible.count - 1, 0))

        switch axis {
        case .vertical:
            let childWidth = availableWidth.map {
                max(0, $0 - padding.left - padding.right)
            }
            return NSSize(
                width: padding.left + padding.right
                    + (visible.map {
                        $0.fittingSize(width: childWidth).width + $0.margin.left + $0.margin.right
                    }
                        .max() ?? 0),
                height: padding.top + padding.bottom + gaps
                    + visible.reduce(0) {
                        $0 + $1.fittingSize(width: childWidth).height
                            + $1.margin.top + $1.margin.bottom
                    })

        case .horizontal:
            return NSSize(
                width: padding.left + padding.right + gaps
                    + visible.reduce(0) {
                        $0 + $1.fittingSize().width + $1.margin.left + $1.margin.right
                    },
                height: padding.top + padding.bottom
                    + (visible.map { $0.fittingSize().height + $0.margin.top + $0.margin.bottom }
                        .max() ?? 0))
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
                    requested: item.width ?? natural.width,
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
                    requested: item.height ?? natural.height,
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
class AppKitSingleChildView: AppKitHitTestView, AppKitWidthConstrainedMeasuring {
    var padding = NSEdgeInsets() {
        didSet { invalidateIntrinsicContentSize(); needsLayout = true }
    }
    private(set) var item: AppKitLayoutItem?

    override var isFlipped: Bool { true }

    func setItem(_ item: AppKitLayoutItem?) {
        replaceSubviews(with: item.map { [$0.view] } ?? [])
        self.item = item
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        fittingContentSize(width: nil)
    }

    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
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

        let content = bounds.inset(by: padding)
        let availableWidth = max(0, content.width - item.margin.left - item.margin.right)
        let availableHeight = max(0, content.height - item.margin.top - item.margin.bottom)
        let natural = item.fittingSize(width: availableWidth)
        let width = extent(
            option: item.horizontal,
            requested: item.width ?? natural.width,
            available: availableWidth,
            minimum: item.minimumWidth,
            maximum: item.maximumWidth)
        let height = extent(
            option: item.vertical,
            requested: item.height ?? natural.height,
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
/// the window. A window overlay is a slot, not a second page: it is composed
/// above the page and transparent to input wherever its child has no hit
/// target.
@MainActor
final class AppKitWindowContentView: NSView {
    private weak var page: NSView?
    private let overlaySurface = AppKitOverlaySurfaceView()

    override var isFlipped: Bool { true }

    func set(page: NSView?, overlay: AppKitLayoutItem?) {
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
        page?.frame = safeAreaRect
        overlaySurface.frame = safeAreaRect
        overlaySurface.layoutSubtreeIfNeeded()
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

/// The visible chrome and content of one page in a navigation stack.
@MainActor
struct AppKitNavigationItem {
    let layout: AppKitLayoutItem
    let title: String?
    let backTitle: String?
    let showsNavigationBar: Bool
    let showsBackButton: Bool
    let titleView: NSView?
    let toolbarItems: [AppKitToolbarItem]
}

/// One page action and the placement policy authored for it.
@MainActor
struct AppKitToolbarItem {
    let view: NSView
    let order: Int32
    let priority: Int
}

/// Native navigation-bar surface that uses AppKit's header material until the
/// application authors an exact color. A solid color bypasses vibrancy so the
/// part beneath the transparent title bar and the part below it draw alike.
@MainActor
private final class AppKitNavigationBarView: NSView {
    private let material = NSVisualEffectView()
    private var controls: [NSView] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material.material = .headerView
        material.blendingMode = .withinWindow
        material.state = .active
        addSubview(material)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitNavigationBarView is created in code")
    }

    func applyBackground(_ color: NSColor?) {
        wantsLayer = color != nil
        layer?.backgroundColor = color?.cgColor
        material.isHidden = color != nil
    }

    func setControls(_ controls: [NSView]) {
        self.controls = controls
        replaceSubviews(with: [material] + controls)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        material.frame = bounds
    }

    var hasSolidBackgroundForTesting: Bool { material.isHidden }
}

/// AppKit's native presentation of the stack whose identity stays in Swift.
///
/// Every page view remains owned by its `MountedNode`; this view adopts only
/// the top one. The arrangement therefore preserves page state without giving
/// AppKit a second navigation model to reconcile with StateUI's path.
@MainActor
final class AppKitNavigationView: AppKitHitTestView {
    var onBack: (() -> Void)?

    private let bar = AppKitNavigationBarView()
    private let backButton = NSButton()
    private let flyoutButton = NSButton()
    private let titleLabel = NSTextField(labelWithString: "")
    private let overflow = NSPopUpButton(frame: .zero, pullsDown: true)
    private var items: [AppKitNavigationItem] = []
    private var flyoutAction: (() -> Void)?
    private var barBackgroundColor: NSColor?
    private var barTextColor: NSColor = .labelColor
    private let barHeight: CGFloat = 44

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        backButton.bezelStyle = .inline
        backButton.font = .systemFont(ofSize: NSFont.systemFontSize)
        backButton.target = self
        backButton.action = #selector(goBack(_:))

        flyoutButton.title = "☰"
        flyoutButton.bezelStyle = .inline
        flyoutButton.target = self
        flyoutButton.action = #selector(openFlyout(_:))

        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        overflow.bezelStyle = .inline
        addSubview(bar)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitNavigationView is created in code")
    }

    override var isFlipped: Bool { true }

    func setItems(_ items: [AppKitNavigationItem]) {
        let previous = self.items.last?.layout.view
        let next = items.last?.layout.view
        self.items = items

        if previous !== next {
            previous?.removeFromSuperview()
            if let next {
                addSubview(next, positioned: .below, relativeTo: bar)
            }
        }

        // A page may be a layer-backed native scroller. Reassert the chrome's
        // ordering after either page reuse or replacement so AppKit never
        // composites that scroller over the fixed navigation surface.
        addSubview(bar, positioned: .above, relativeTo: next)

        updateChrome()
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    func applyBar(backgroundColor: NSColor?, textColor: NSColor?) {
        barBackgroundColor = backgroundColor
        barTextColor = textColor ?? .labelColor
        bar.applyBackground(backgroundColor)
        updateChrome()
    }

    override var intrinsicContentSize: NSSize {
        guard let item = items.last else { return NSSize(width: 0, height: barHeight) }
        let size = item.layout.fittingSize()
        return NSSize(
            width: size.width + item.layout.margin.left + item.layout.margin.right,
            height: size.height + item.layout.margin.top + item.layout.margin.bottom
                + (item.showsNavigationBar ? effectiveBarHeight : 0))
    }

    override func layout() {
        super.layout()
        guard let item = items.last else {
            bar.isHidden = true
            return
        }

        bar.isHidden = !item.showsNavigationBar
        let top = item.showsNavigationBar ? effectiveBarHeight : 0
        if item.showsNavigationBar {
            bar.frame = NSRect(x: 0, y: 0, width: bounds.width, height: effectiveBarHeight)
            let leading = backButton.isHidden ? flyoutButton : backButton
            let leadingWidth = leading.isHidden ? 0 : min(max(leading.fittingSize.width, 36), 160)
            leading.frame = NSRect(
                x: 10, y: safeAreaInsets.top + 7,
                width: leadingWidth, height: 30)
            var toolbarX = bounds.width - 10
            for control in visibleToolbarViews(for: item).reversed() {
                let width = min(max(control.fittingSize.width, 36), 140)
                toolbarX -= width
                control.frame = NSRect(
                    x: toolbarX, y: safeAreaInsets.top + 7,
                    width: width, height: 30)
                toolbarX -= 6
            }

            let title = item.titleView ?? titleLabel
            title.frame = NSRect(
                x: max(16, leadingWidth + 18),
                y: safeAreaInsets.top + 7,
                width: max(0, toolbarX - max(16, leadingWidth + 18)),
                height: 30)
        }

        let margin = item.layout.margin
        item.layout.view.frame = NSRect(
            x: margin.left,
            y: top + margin.top,
            width: max(0, bounds.width - margin.left - margin.right),
            height: max(0, bounds.height - top - margin.top - margin.bottom))
    }

    private func updateChrome() {
        guard let top = items.last else {
            bar.isHidden = true
            return
        }

        titleLabel.stringValue = top.title ?? ""
        titleLabel.textColor = barTextColor

        let canGoBack = items.count > 1 && top.showsBackButton
        backButton.isHidden = !canGoBack
        flyoutButton.isHidden = canGoBack || flyoutAction == nil
        backButton.title = canGoBack ? "‹ \(items.dropLast().last?.backTitle ?? "Back")" : ""
        backButton.contentTintColor = barTextColor
        bar.isHidden = !top.showsNavigationBar
        rebuildOverflow(for: top)
        bar.setControls(
            [backButton, flyoutButton, top.titleView ?? titleLabel]
                + visibleToolbarViews(for: top))
    }

    private func visibleToolbarViews(for item: AppKitNavigationItem) -> [NSView] {
        let primary = item.toolbarItems.enumerated()
            .filter { $0.element.order != 2 }
            .sorted {
                $0.element.priority == $1.element.priority
                    ? $0.offset < $1.offset
                    : $0.element.priority < $1.element.priority
            }
            .map(\.element.view)
        return item.toolbarItems.contains(where: { $0.order == 2 })
            ? primary + [overflow]
            : primary
    }

    private var effectiveBarHeight: CGFloat {
        barHeight + safeAreaInsets.top
    }

    private func rebuildOverflow(for item: AppKitNavigationItem) {
        overflow.removeAllItems()
        overflow.addItem(withTitle: "•••")

        for toolbarItem in item.toolbarItems where toolbarItem.order == 2 {
            guard let button = toolbarItem.view as? NSButton else { continue }
            let menuItem = NSMenuItem(
                title: button.title,
                action: #selector(NSButton.performClick(_:)),
                keyEquivalent: "")
            menuItem.target = button
            menuItem.image = button.image
            menuItem.isEnabled = button.isEnabled
            overflow.menu?.addItem(menuItem)
        }
    }

    @objc private func goBack(_ sender: Any?) {
        guard items.count > 1, items.last?.showsBackButton == true else { return }
        onBack?()
    }

    @objc private func openFlyout(_ sender: Any?) {
        flyoutAction?()
    }

    func setFlyoutAction(_ action: (() -> Void)?) {
        flyoutAction = action
        updateChrome()
        needsLayout = true
    }

    func goBackForTesting() { goBack(nil) }
    var titleForTesting: String { titleLabel.stringValue }
    var backTitleForTesting: String { items.dropLast().last?.backTitle ?? "Back" }
    var showsBackButtonForTesting: Bool { !backButton.isHidden }
    var hasSolidBarBackgroundForTesting: Bool { bar.hasSolidBackgroundForTesting }
    var navigationBarIsFrontmostForTesting: Bool {
        !bar.isHidden && subviews.last === bar
    }
    var titleViewForTesting: NSView? { items.last?.titleView }
    var toolbarItemCountForTesting: Int { items.last?.toolbarItems.count ?? 0 }

    func clickToolbarItemForTesting(_ index: Int) {
        guard let toolbarItems = items.last?.toolbarItems,
              toolbarItems.indices.contains(index)
        else { return }
        (toolbarItems[index].view as? NSButton)?.performClick(nil)
    }
}

/// One page offered by a native AppKit tab bar.
@MainActor
struct AppKitTabItem {
    let layout: AppKitLayoutItem
    let title: String?
    let image: NSImage?
}

/// A native tab selector over the page arrangement StateUI owns.
@MainActor
final class AppKitTabbedView: AppKitHitTestView {
    var onSelection: ((_ previous: Int, _ selected: Int) -> Void)?

    private let selector = NSSegmentedControl()
    private var items: [AppKitTabItem] = []
    private(set) var selectedIndex = -1
    private let barHeight: CGFloat = 40

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        selector.trackingMode = .selectOne
        selector.segmentStyle = .automatic
        selector.target = self
        selector.action = #selector(selectionChanged(_:))
        addSubview(selector)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitTabbedView is created in code")
    }

    override var isFlipped: Bool { true }

    /// Reconciles the native selector and returns a platform fallback only
    /// when the selected page itself disappeared from the arrangement.
    func setItems(_ items: [AppKitTabItem], requestedIndex: Int?) -> Int? {
        let formerView = item(at: selectedIndex)?.layout.view
        let formerIndex = selectedIndex
        self.items = items

        selector.segmentCount = items.count
        for (index, item) in items.enumerated() {
            selector.setLabel(item.title ?? "", forSegment: index)
            selector.setImage(item.image, forSegment: index)
        }

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

        show(next, replacing: formerView)
        return fallback
    }

    func applyBar(
        backgroundColor: NSColor?,
        selectedColor: NSColor?,
        unselectedColor: NSColor?
    ) {
        wantsLayer = backgroundColor != nil
        layer?.backgroundColor = backgroundColor?.cgColor
        _ = selectedColor
        _ = unselectedColor
    }

    override var intrinsicContentSize: NSSize {
        guard let item = item(at: selectedIndex) else {
            return NSSize(width: selector.fittingSize.width, height: barHeight)
        }

        let size = item.layout.fittingSize()
        return NSSize(
            width: max(selector.fittingSize.width,
                size.width + item.layout.margin.left + item.layout.margin.right),
            height: barHeight + size.height + item.layout.margin.top + item.layout.margin.bottom)
    }

    override func layout() {
        super.layout()
        selector.frame = NSRect(x: 10, y: 5, width: max(0, bounds.width - 20), height: 30)

        guard let item = item(at: selectedIndex) else { return }
        let margin = item.layout.margin
        item.layout.view.frame = NSRect(
            x: margin.left,
            y: barHeight + margin.top,
            width: max(0, bounds.width - margin.left - margin.right),
            height: max(0, bounds.height - barHeight - margin.top - margin.bottom))
    }

    @objc private func selectionChanged(_ sender: NSSegmentedControl) {
        let next = sender.selectedSegment
        guard items.indices.contains(next), next != selectedIndex else { return }
        let previous = selectedIndex
        show(next)
        onSelection?(previous, next)
    }

    private func show(_ index: Int, replacing previousView: NSView? = nil) {
        let previous = previousView ?? item(at: selectedIndex)?.layout.view
        let next = item(at: index)?.layout.view

        if previous !== next {
            previous?.removeFromSuperview()
        }
        selectedIndex = index
        selector.selectedSegment = index

        if let view = next, view.superview !== self {
            addSubview(view, positioned: .below, relativeTo: selector)
        }

        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    func selectForTesting(_ index: Int) {
        selector.selectedSegment = index
        selectionChanged(selector)
    }

    var selectedIndexForTesting: Int { selectedIndex }

    private func item(at index: Int) -> AppKitTabItem? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }
}

/// A StateUI flyout presented by AppKit's native split-view controller.
///
/// Swift remains the owner of the two page identities and of the presented
/// value. The controller owns the platform's sidebar, divider, resizing, and
/// collapse behavior; the stable pane views merely adopt the native views
/// mounted by the renderer.
@MainActor
final class AppKitFlyoutView: AppKitHitTestView {
    var onPresentationChanged: ((Bool) -> Void)?

    private let splitController = NSSplitViewController()
    private let sidebarController = NSViewController()
    private let detailController = NSViewController()
    private let sidebarSurface = AppKitSingleChildView()
    private let detailSurface = AppKitSingleChildView()
    private lazy var sidebarItem = NSSplitViewItem(
        sidebarWithViewController: sidebarController)
    private lazy var detailItem = NSSplitViewItem(
        viewController: detailController)
    private var requestedPresentation = false
    private var behavior: Int32 = 0
    private var gesturesEnabled = true
    private var applyingPresentation = false
    private var lastEffectivePresentation = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        sidebarController.view = sidebarSurface
        detailController.view = detailSurface
        sidebarItem.canCollapse = true
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
        fatalError("AppKitFlyoutView is created in code")
    }

    override var isFlipped: Bool { true }

    func setItems(_ items: [AppKitLayoutItem]) {
        let nextDetail = items.count > 1 ? items[1] : nil
        let previousDetail = detailSurface.item?.view

        if previousDetail !== nextDetail?.view {
            (previousDetail as? AppKitNavigationView)?.setFlyoutAction(nil)
        }

        sidebarSurface.setItem(items.first)
        detailSurface.setItem(nextDetail)
        (nextDetail?.view as? AppKitNavigationView)?.setFlyoutAction { [weak self] in
            self?.settlePresentation(true)
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    /// Applies Swift's value without echoing it. A behavior that requires a
    /// visible sidebar may settle on `true`; that native answer is returned to
    /// the binding.
    func apply(presented: Bool, behavior: Int32, gesturesEnabled: Bool) -> Bool? {
        requestedPresentation = presented
        self.behavior = behavior
        self.gesturesEnabled = gesturesEnabled

        let effective = forcesSidebarVisible || requestedPresentation
        setSidebarPresented(effective, reporting: false)
        return effective == presented ? nil : effective
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
        setSidebarPresented(
            forcesSidebarVisible || requestedPresentation,
            reporting: true)
        splitController.view.layoutSubtreeIfNeeded()

        // A detached NSSplitViewController has no parent view controller to
        // constrain its split view. AppKit otherwise keeps the panes at their
        // fitting height, allowing a tall document to escape above this host
        // surface. The native split view owns pane layout within these bounds.
        splitController.splitView.frame = splitController.view.bounds
        splitController.splitView.needsLayout = true
        splitController.splitView.layoutSubtreeIfNeeded()

        if !sidebarItem.isCollapsed, splitController.splitView.subviews.count > 1 {
            let width = min(max(260, bounds.width * 0.28), 340)
            splitController.splitView.setPosition(width, ofDividerAt: 0)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard gesturesEnabled, !forcesSidebarVisible,
              abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY),
              abs(event.scrollingDeltaX) >= 12
        else {
            super.scrollWheel(with: event)
            return
        }

        settlePresentation(event.scrollingDeltaX > 0)
    }

    private var forcesSidebarVisible: Bool {
        switch behavior {
        case 2:
            return true
        case 3:
            return bounds.width > bounds.height
        case 4:
            return bounds.height > bounds.width
        case 0:
            return bounds.width >= 720
        default:
            return false
        }
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

    private func settlePresentation(_ presented: Bool) {
        guard !forcesSidebarVisible, requestedPresentation != presented else { return }
        requestedPresentation = presented
        setSidebarPresented(presented, reporting: true)
    }

    @objc private func splitViewResized(_ notification: Notification) {
        guard !applyingPresentation else { return }
        let presented = !sidebarItem.isCollapsed

        if forcesSidebarVisible, !presented {
            setSidebarPresented(true, reporting: true)
            return
        }

        guard presented != lastEffectivePresentation else { return }
        requestedPresentation = presented
        lastEffectivePresentation = presented
        onPresentationChanged?(presented)
    }

    var isEffectivelyPresented: Bool { !sidebarItem.isCollapsed }
    func toggleForTesting() { settlePresentation(!isEffectivelyPresented) }
    var isEffectivelyPresentedForTesting: Bool { isEffectivelyPresented }
    var splitControllerForTesting: NSSplitViewController { splitController }
}

/// One parsed row or column definition in a StateUI grid.
struct AppKitGridLength {
    enum Kind {
        case absolute
        case star
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
        case 0: kind = .absolute
        case 1: kind = .star
        case 2: kind = .auto
        default: return nil
        }

        self.value = max(0, amount)
    }
}

/// AppKit's deterministic implementation of StateUI's row-and-column layout.
@MainActor
final class AppKitGridView: AppKitHitTestView {
    var rows: [AppKitGridLength] = [] { didSet { invalidateIntrinsicContentSize(); needsLayout = true } }
    var columns: [AppKitGridLength] = [] { didSet { invalidateIntrinsicContentSize(); needsLayout = true } }
    var rowSpacing: CGFloat = 0 { didSet { invalidateIntrinsicContentSize(); needsLayout = true } }
    var columnSpacing: CGFloat = 0 { didSet { invalidateIntrinsicContentSize(); needsLayout = true } }
    var padding = NSEdgeInsets() { didSet { invalidateIntrinsicContentSize(); needsLayout = true } }
    private var items: [AppKitLayoutItem] = []

    override var isFlipped: Bool { true }

    func setItems(_ items: [AppKitLayoutItem]) {
        replaceSubviews(with: items.map(\.view))
        self.items = items
        invalidateIntrinsicContentSize()
        needsLayout = true
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
                requested: item.width ?? natural.width,
                available: availableWidth,
                minimum: item.minimumWidth,
                maximum: item.maximumWidth)
            let height = extent(
                option: item.vertical,
                requested: item.height ?? natural.height,
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
            repeating: AppKitGridLength(kind: .star, value: 1),
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

        for index in 0..<count where definitions[index].kind == .absolute {
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
            $0 + ($1.kind == .star ? max($1.value, 0.000_001) : 0)
        }
        let remainder = max(0, (available ?? fixed) - fixed)

        for index in 0..<count where definitions[index].kind == .star {
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
        invalidateIntrinsicContentSize()
        needsLayout = true
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
        invalidateIntrinsicContentSize()
        needsLayout = true
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
        if handsWheelToEnclosingScroller(event),
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

    /// A one-axis viewport owns gestures along that axis. A dominant gesture
    /// along its disabled axis belongs to the nearest enclosing viewport, so a
    /// horizontal strip does not interrupt its vertical page.
    private func handsWheelToEnclosingScroller(_ event: NSEvent) -> Bool {
        let horizontal = abs(event.scrollingDeltaX)
        let vertical = abs(event.scrollingDeltaY)
        guard max(horizontal, vertical) > 0.000_001 else { return false }

        return switch orientation {
        case .horizontal:
            !event.modifierFlags.contains(.shift) && vertical > horizontal
        case .vertical:
            horizontal > vertical
        case .both:
            false
        case .neither:
            true
        }
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
private final class AppKitScrollDocumentView: NSView {
    var item: AppKitLayoutItem? {
        didSet { replaceSubviews(with: item.map { [$0.view] } ?? []) }
    }
    var padding = NSEdgeInsets()
    var orientation = ScrollOrientation.vertical

    override var isFlipped: Bool { true }

    func fittingContentSize(width availableWidth: CGFloat?) -> NSSize {
        guard let item else { return .zero }

        let horizontalInsets = padding.left + padding.right + item.margin.left + item.margin.right
        let verticalInsets = padding.top + padding.bottom + item.margin.top + item.margin.bottom
        let constrainedWidth: CGFloat? = orientation == .vertical || orientation == .neither
            ? availableWidth.map { max(0, $0 - horizontalInsets) }
            : nil
        let natural = item.fittingSize(width: constrainedWidth)
        let contentWidth = item.horizontal == 3
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
        let width = item.boundedWidth(
            item.width ?? (item.horizontal == 3 ? room.width : natural.width),
            available: room.width)
        let height = item.boundedHeight(
            item.height ?? (item.vertical == 3 ? room.height : natural.height),
            available: room.height)
        let x: CGFloat = switch item.horizontal {
        case 1: room.midX - width / 2
        case 2: room.maxX - width
        default: room.minX
        }
        let y: CGFloat = switch item.vertical {
        case 1: room.midY - height / 2
        case 2: room.maxY - height
        default: room.minY
        }
        item.view.frame = NSRect(x: x, y: y, width: max(0, width), height: max(0, height))
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
        strokeShape: HostValue?
    ) {
        fill = AppKitBrush(background) ?? AppKitBrush(color: backgroundColor)
        self.stroke = AppKitBrush(stroke) ?? AppKitBrush()
        self.strokeWidth = max(0, strokeWidth ?? 1)
        shape = AppKitBorderShape(strokeShape)
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

func nsColor(_ value: HostValue) -> NSColor? {
    guard let color = value.color else { return nil }
    return NSColor(
        calibratedRed: CGFloat(color.red) / 255,
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

private func extent(
    option: Int32,
    requested: CGFloat,
    available: CGFloat,
    minimum: CGFloat? = nil,
    maximum: CGFloat? = nil
) -> CGFloat {
    appKitBoundedExtent(
        option == 3 ? available : requested,
        minimum: minimum,
        maximum: maximum,
        available: available)
}

private func position(option: Int32, extent: CGFloat, start: CGFloat, available: CGFloat) -> CGFloat {
    switch option {
    case 1: return start + max(0, available - extent) / 2
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

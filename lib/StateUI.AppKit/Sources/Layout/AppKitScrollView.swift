// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// A native scroll surface: its document geometry, its offset reported on the
/// display's frames, and the moment it comes to rest. Where it rests is the
/// platform's - an application that wants it somewhere else writes the offset
/// when it hears it stop.
@MainActor
final class AppKitScrollView: NSScrollView, AppKitWidthConstrainedMeasuring {
    var onOffsetChanged: ((NSPoint, NSPoint) -> Void)?
    var onScrollStopped: (() -> Void)?

    /// Asks for the display's frames: the scroller is moving or has something
    /// to say, and it says it only on a frame - see `frame(now:)`.
    var onFramesWanted: (() -> Void)?

    private(set) var orientation = ScrollOrientation.vertical
    private(set) var padding = NSEdgeInsets()
    private var verticalBarVisibility: Int32 = 0
    private var horizontalBarVisibility: Int32 = 0

    private let documentSurface = AppKitScrollDocumentView()
    private let stackWrapper = AppKitStackView(axis: .vertical)
    private var usesStackWrapper = false
    private var pendingOffset: NSPoint?
    private var lastObservedOffset = NSPoint.zero
    private var gestureScroller: WheelScroller?

    /// The user's movement of this scroller, and its rest.
    private let movement = ScrollMovement()

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
        movement.onFramesWanted = { [weak self] in self?.onFramesWanted?() }

        // BORN IN ITS CONTRACT'S DEFAULT STATE. A registration applies on
        // CHANGE, so a scroller nothing describes would otherwise keep
        // AppKit's own resting state - no vertical scroller - where the
        // contract says a scroller scrolls vertically. Applied through the
        // same path, so the two can never drift apart.
        apply(
            orientation: ScrollOrientation.vertical.rawValue,
            padding: NSEdgeInsets(),
            verticalBarVisibility: 0,
            horizontalBarVisibility: 0,
            offset: nil)

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
        offset: NSPoint?
    ) {
        self.orientation = ScrollOrientation(rawValue: orientation) ?? .vertical
        self.padding = padding
        self.verticalBarVisibility = verticalBarVisibility
        self.horizontalBarVisibility = horizontalBarVisibility
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
            // An offset the scroller already stands at is not written again:
            // the user's own report comes back as the state it wrote, and
            // moving the clip view to where it stands mid-gesture interrupts
            // the platform's own scroll on every report.
            if abs(offset.x - lastObservedOffset.x) < 0.5, abs(offset.y - lastObservedOffset.y) < 0.5 {
                pendingOffset = nil
            } else {
                pendingOffset = offset
                if documentSurface.frame.width > 0, documentSurface.frame.height > 0 {
                    move(to: offset, asUser: false)
                    pendingOffset = nil
                }
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
            move(to: pendingOffset, asUser: false)
        } else {
            move(to: contentView.bounds.origin, asUser: false)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if wheelScroller(for: event) == .enclosing,
            let enclosingScroller = enclosingScrollView {
            enclosingScroller.scrollWheel(with: event)
            return
        }

        super.scrollWheel(with: event)
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
        movement.holdBegan()
    }

    /// A live scroll ends when the movement it began has run out.
    @objc private func didEndLiveScroll(_ notification: Notification) {
        movement.holdEnded(rests: true)
    }

    @objc private func clipBoundsChanged(_ notification: Notification) {
        guard !ProgramWrite.isWriting else { return }
        let current = offset
        guard current != lastObservedOffset else { return }
        // WHERE IT STANDS FIRST, then the report: the report runs the render
        // that writes the state back, and that write is told apart from an
        // application's by where the scroller already stands.
        let previous = lastObservedOffset
        lastObservedOffset = current
        movement.userMoved(from: Point(previous), to: Point(current))
    }

    /// How many times something other than the user moved the scroller.
    private(set) var programmaticMovesForTesting = 0

    private func move(to requested: NSPoint, asUser: Bool) {
        if !asUser { programmaticMovesForTesting += 1 }
        let old = offset
        let target = reachable(normalized(requested))
        ProgramWrite.perform {
            contentView.scroll(to: target)
            reflectScrolledClipView(contentView)
        }
        let current = offset
        lastObservedOffset = current

        if asUser {
            movement.userMoved(from: Point(old), to: Point(current))
        }
    }

    /// Whether the scroller needs the display's frames: it is moving, or it
    /// has something to say.
    var wantsFrames: Bool { movement.wantsFrames }

    /// One frame of the display's clock. What the scroller has to say is said
    /// here and nowhere else, in order: where it went, and that it came to
    /// rest.
    func frame(now: Double) {
        for report in movement.frame(now: now) {
            switch report {
            case .moved(let from, let to):
                onOffsetChanged?(NSPoint(x: from.x, y: from.y), NSPoint(x: to.x, y: to.y))
            case .rested:
                onScrollStopped?()
            }
        }
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
            x: Self.reachable(point.x, content: documentSize.width, viewport: contentSize.width),
            y: Self.reachable(point.y, content: documentSize.height, viewport: contentSize.height))
    }

    /// An offset inside measured content. Before either extent is known only
    /// the leading edge can be enforced without discarding a pending offset.
    private static func reachable(_ offset: CGFloat, content: CGFloat, viewport: CGFloat) -> CGFloat {
        let leading = max(0, offset.isFinite ? offset : 0)
        guard content.isFinite, viewport.isFinite, content > 0, viewport > 0 else {
            return leading
        }
        return min(leading, max(0, content - viewport))
    }

    func beginMovementForTesting() {
        movement.begin()
    }

    func moveAsUserForTesting(to point: NSPoint) {
        move(to: point, asUser: true)
    }

    func restForTesting() {
        movement.rest()
    }
}

@MainActor
private final class AppKitScrollDocumentView: NSView, AppKitMeasurementCaching {
    let measurements = MeasurementCache()
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
        NSSize(ScrollArithmetic.contentSize(
            of: item, padding: Insets(padding), orientation: orientation,
            width: availableWidth.map(Double.init)))
    }

    func arrange(in viewport: NSSize) {
        guard let item else {
            frame.size = viewport
            return
        }

        let arranged = ScrollArithmetic.arrange(
            item, padding: Insets(padding), orientation: orientation, in: LayoutSize(viewport))
        frame = NSRect(origin: .zero, size: NSSize(arranged.document))
        item.view.frame = NSRect(placed: arranged.place)
        item.view.needsLayout = true
    }
}

#endif

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// Native StateUI containers measure their descendants against the width the
/// parent actually offers. AppKit's unconstrained `fittingSize` cannot carry
/// that proposal through frame-based containers, so wrapped native text would
/// otherwise grow only after its ancestors had already chosen their heights.
@MainActor
protocol AppKitWidthConstrainedMeasuring: AnyObject {
    func fittingContentSize(width: CGFloat?) -> NSSize
}

extension MeasurementCache {
    /// The size measured for `width`, in AppKit's units, measuring only when none is kept.
    func size(offering width: CGFloat?, measure: () -> NSSize) -> NSSize {
        let size = size(offering: width.map(Double.init)) { LayoutSize(measure()) }
        return NSSize(width: size.width, height: size.height)
    }
}

extension LayoutSize {
    /// A native size as the layout arithmetic's.
    init(_ size: NSSize) {
        self.init(width: Double(size.width), height: Double(size.height))
    }
}

extension NSSize {
    /// The layout arithmetic's size as a native one.
    init(_ size: LayoutSize) {
        self.init(width: size.width, height: size.height)
    }
}

extension Point {
    /// A native point as StateUI's.
    init(_ point: NSPoint) {
        self.init(x: Double(point.x), y: Double(point.y))
    }
}

extension Insets {
    /// Native edge insets as StateUI's.
    init(_ insets: NSEdgeInsets) {
        self.init(Double(insets.left), Double(insets.top), Double(insets.right), Double(insets.bottom))
    }
}

/// A StateUI container or text surface that keeps its own measurements.
@MainActor
protocol AppKitMeasurementCaching: AnyObject {
    var measurements: MeasurementCache { get }
}

/// A container whose size its place decides - a split view's pane, a window's
/// content - and which gives its child all of it.
///
/// A change inside a room is laid out inside it: the measurement climb stops
/// below the room, and nothing around it is asked. A label's report that
/// climbed on into a split view item's glass container made every window
/// update wait ~90 ms for it.
@MainActor
protocol AppKitRoom: NSView {}

@MainActor
extension NSView {
    /// Forgets the measurement of this view and of every ancestor whose size
    /// can follow it, and asks each of them to lay out again.
    ///
    /// The climb goes over the native views a container keeps inside itself -
    /// a scroller's clip view, a tab view - and stops below a room, or at the
    /// window's content. A change that cannot alter a size never calls this,
    /// so nothing beside it moves.
    func invalidateMeasurements() {
        var current: NSView? = self

        while let view = current {
            (view as? AppKitMeasurementCaching)?.measurements.invalidate()
            view.needsLayout = true

            guard view !== view.window?.contentView,
                  let above = view.superview,
                  !(above is AppKitRoom)
            else { break }

            // What the parent reads when it measures this view; a room does
            // not measure its child, so the view below one keeps its answer.
            view.invalidateIntrinsicContentSize()
            current = above
        }
    }
}

extension NSRect {
    func inset(by insets: NSEdgeInsets) -> NSRect {
        NSRect(
            x: origin.x + insets.left,
            y: origin.y + insets.top,
            width: max(0, width - insets.left - insets.right),
            height: max(0, height - insets.top - insets.bottom))
    }
}

@MainActor
extension NSView {
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

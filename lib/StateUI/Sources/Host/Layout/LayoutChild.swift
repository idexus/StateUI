// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A width and a height, in points.
@_spi(Host) public struct LayoutSize: Equatable, Sendable {
    /// How wide.
    public var width: Double

    /// How tall.
    public var height: Double

    /// A size `width` wide and `height` tall.
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// No room at all.
    public static let zero = LayoutSize(width: 0, height: 0)
}

/// What a layout reads of one child: its margin, alignments, stated sizes and place in a grid or a ZStack.
/// Design: docs/design/host/layout.md#the-layout-arithmetic
@_spi(Host) public struct LayoutValues: Equatable, Sendable {
    /// The space kept around the child, outside it.
    public var margin = Insets(0)

    /// Across its slot: 0 start, 1 centre, 2 end, 3 fill.
    public var horizontal: Int32 = 3

    /// Down its slot: 0 start, 1 centre, 2 end, 3 fill.
    public var vertical: Int32 = 3

    /// The width the child states for itself.
    public var width: Double?

    /// The height the child states for itself.
    public var height: Double?

    /// The least width the child takes.
    public var minimumWidth: Double?

    /// The least height the child takes.
    public var minimumHeight: Double?

    /// The most width the child takes.
    public var maximumWidth: Double?

    /// The most height the child takes.
    public var maximumHeight: Double?

    /// The grid row the child starts in.
    public var row = 0

    /// The grid column the child starts in.
    public var column = 0

    /// How many grid rows the child spans.
    public var rowSpan = 1

    /// How many grid columns the child spans.
    public var columnSpan = 1

    /// The part of a ZStack's room the child stands in; the whole room where it names none.
    public var area: Area?

    /// Values with every part at its default.
    public init() {}

    /// The width a child is measured at for the width its layout offers: its stated width, within its bounds - so
    /// its words wrap to it - else the smaller of the offer and its most width.
    /// Design: docs/design/host/layout.md#a-child-measured
    public func offer(_ width: Double?) -> Double? {
        if let stated = self.width { return boundedWidth(stated) }
        return [width, maximumWidth].compactMap { $0 }.min()
    }

    /// A child's size from what it measured: a stated width or height before the measured one, each within its
    /// bounds.
    public func sized(_ measured: LayoutSize) -> LayoutSize {
        LayoutSize(width: boundedWidth(width ?? measured.width), height: boundedHeight(height ?? measured.height))
    }

    /// `proposed`, held within the child's least and most width and the room `available`.
    public func boundedWidth(_ proposed: Double, available: Double? = nil) -> Double {
        Extent.bounded(proposed, minimum: minimumWidth, maximum: maximumWidth, available: available)
    }

    /// `proposed`, held within the child's least and most height and the room `available`.
    public func boundedHeight(_ proposed: Double, available: Double? = nil) -> Double {
        Extent.bounded(proposed, minimum: minimumHeight, maximum: maximumHeight, available: available)
    }
}

/// A child as the layout arithmetic sees it; a toolkit's child measures its own view.
@_spi(Host) @MainActor public protocol LayoutChild {
    /// What the layout reads of the child.
    var values: LayoutValues { get }

    /// Whether the child is shown; a hidden child takes no room.
    var isShown: Bool { get }

    /// The child's own size for the width offered to it, its margin already taken out - the layout owns the
    /// margin, both ways; its stated sizes and bounds applied.
    func size(offered width: Double?) -> LayoutSize
}

/// The arithmetic of one child's extent and place along one axis of its slot.
/// Design: docs/design/host/layout.md#one-axis-of-a-slot
@_spi(Host) public enum Extent {
    /// `proposed` within `minimum`, `maximum` and the room `available`; the minimum wins a contradiction.
    public static func bounded(_ proposed: Double, minimum: Double?, maximum: Double?, available: Double? = nil) -> Double {
        let lower = max(0, minimum ?? 0)
        let upper = max(lower, maximum ?? .greatestFiniteMagnitude)
        let finite = proposed.isFinite ? proposed : lower
        var result = max(min(max(0, finite), upper), lower)
        if let available, available.isFinite { result = min(result, max(0, available)) }
        return result
    }

    /// A child's extent in its slot: a stated size wins; else a filling child takes the slot, any other its natural size.
    public static func of(
        option: Int32,
        stated: Double?,
        natural: Double,
        available: Double,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) -> Double {
        bounded(stated ?? (option == 3 ? available : natural), minimum: minimum, maximum: maximum, available: available)
    }

    /// Where a child of `extent` starts in its slot; a filling child that stops short stands in the middle.
    public static func start(option: Int32, extent: Double, start: Double, available: Double) -> Double {
        switch option {
        case 1, 3: return start + max(0, available - extent) / 2
        case 2: return start + max(0, available - extent)
        default: return start
        }
    }
}

/// The sizes one view measured, by the width its parent offered, kept until something changes them.
/// Design: docs/design/host/layout.md#measured-once
@_spi(Host) @MainActor public final class MeasurementCache {
    private var sizes: [(width: Double?, size: LayoutSize)] = []

    /// A cache holding nothing yet.
    public init() {}

    /// The size measured for `width`, measuring only when none is kept.
    public func size(offering width: Double?, measure: () -> LayoutSize) -> LayoutSize {
        if let kept = sizes.first(where: { $0.width == width }) { return kept.size }

        let measured = measure()
        if sizes.count == Self.capacity { sizes.removeFirst() }
        sizes.append((width, measured))
        return measured
    }

    /// Forgets every kept size.
    public func invalidate() {
        sizes.removeAll(keepingCapacity: true)
    }

    /// A parent offers a view one or two widths in a pass: its natural width and the width it lays it out in.
    private static let capacity = 4
}

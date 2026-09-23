// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `PositionIndicator`'s own properties, shared by the control and its
/// `Style<PositionIndicator>`.
public protocol PositionIndicatorProperties: PropertyContainer {}

extension PositionIndicatorProperties {
    /// How many dots there are.
    ///
    /// The other way to say it is `PositionIndicator(items) { … }`, which counts
    /// its items itself - one or the other, never both.
    public func count(_ value: Int) -> Modified {
        setValue(PositionIndicatorContract.count, value)
    }

    /// Which dot is the current one, counting from 0 - usually the state a
    /// gallery's `position($shown)` writes.
    public func position(_ value: Int) -> Modified {
        setValue(PositionIndicatorContract.position, value)
    }

    /// The colour of a dot that is not the current one.
    public func indicatorColor(_ value: Color) -> Modified {
        setValue(PositionIndicatorContract.indicatorColor, value)
    }

    /// And of the one that is.
    public func selectedIndicatorColor(_ value: Color) -> Modified {
        setValue(PositionIndicatorContract.selectedIndicatorColor, value)
    }

    /// How big each dot is, in device units.
    public func indicatorSize(_ value: Double) -> Modified {
        setValue(PositionIndicatorContract.indicatorSize, value)
    }

    /// The most dots to draw, however many items there are.
    public func maximumVisible(_ value: Int) -> Modified {
        setValue(PositionIndicatorContract.maximumVisible, value)
    }

    /// A dot or a square, for every dot.
    public func indicatorsShape(_ value: IndicatorShape) -> Modified {
        setValue(PositionIndicatorContract.indicatorsShape, value)
    }

    /// Whether one lonely dot is hidden rather than drawn. True by default.
    public func hideSingle(_ value: Bool) -> Modified {
        setValue(PositionIndicatorContract.hideSingle, value)
    }
}

/// The row of dots under a run of cards, saying how many there are and which
/// one is showing.
///
///     PositionIndicator()
///         .count(cards.count)
///         .position(shown)
///         .indicatorColor(.lightGray)
///         .selectedIndicatorColor(.cornflowerBlue)
///
/// It is joined to a `GalleryView` by shared state: the gallery's
/// `.position($shown)` writes it as the user swipes, and `.position(shown)`
/// here reads it. It serves anything with a place in a sequence.
public struct PositionIndicator: View, PositionIndicatorProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<PositionIndicator>` is written against.
    public init() {
        node = Node(contract: PositionIndicatorContract.self)
    }

    /// Each dot is described as a view of its own and built from the supplied
    /// content closure.
    ///
    ///     PositionIndicator(cards) { _ in
    ///         Image("diamond.png")
    ///     }
    ///     .position(shown)
    ///
    /// The items take the place of `count`, which is derived from them.
    public init<Items: RandomAccessCollection>(
        _ items: Items,
        content: (Items.Element) -> Element
    ) {
        node = Node(contract: PositionIndicatorContract.self, children: items.map { content($0).body })
    }

}

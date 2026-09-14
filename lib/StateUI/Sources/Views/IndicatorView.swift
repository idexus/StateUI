// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// IndicatorView's own properties - the half a `Style<IndicatorView>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol IndicatorViewProperties: PropertyContainer {}

extension IndicatorViewProperties {
    /// How many dots there are.
    ///
    /// The other way to say it is `IndicatorView(items) { … }`, which counts
    /// its items itself - one or the other, never both.
    public func count(_ value: Int) -> Modified {
        setValue(.count, .number(Double(value)))
    }

    /// Which one is the current one, counting from 0.
    ///
    /// Told to it rather than read from it: nothing about an IndicatorView is
    /// the reader's to change, so there is no binding overload here - a
    /// gallery's `position($shown)` is what writes, and this reads the same
    /// state.
    public func position(_ value: Int) -> Modified {
        setValue(.position, .number(Double(value)))
    }

    /// The colour of a dot that is not the current one.
    public func indicatorColor(_ value: Color) -> Modified {
        setValue(.indicatorColor, value.propValue)
    }

    /// And of the one that is.
    public func selectedIndicatorColor(_ value: Color) -> Modified {
        setValue(.selectedIndicatorColor, value.propValue)
    }

    /// How big each dot is, in device units.
    public func indicatorSize(_ value: Double) -> Modified {
        setValue(.indicatorSize, .number(value))
    }

    /// The most dots to draw, however many items there are.
    public func maximumVisible(_ value: Int) -> Modified {
        setValue(.maximumVisible, .number(Double(value)))
    }

    /// A dot or a square, for every dot. The modifier's name is plural and the
    /// enum's is not.
    public func indicatorsShape(_ value: IndicatorShape) -> Modified {
        setValue(.indicatorsShape, value.propValue)
    }

    /// Whether one lonely dot is hidden rather than drawn. True by default.
    public func hideSingle(_ value: Bool) -> Modified {
        setValue(.hideSingle, .bool(value))
    }
}

/// The row of dots under a run of cards, saying how many there are and which
/// one is showing.
///
///     IndicatorView()
///         .count(cards.count)
///         .position(shown)
///         .indicatorColor(.lightGray)
///         .selectedIndicatorColor(.cornflowerBlue)
///
/// It is joined to a `GalleryView` by SHARED STATE rather than by naming one:
/// `GalleryView { … }.position($shown)` writes that state as the reader swipes,
/// and `.position(shown)` here reads the same value back. Which is also what
/// makes an IndicatorView useful on its own - a wizard, a stepper, anything
/// with a place in a sequence.
public struct IndicatorView: View, IndicatorViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<IndicatorView>` is written against.
    public init() {
        node = Node(type: .indicatorView)
    }

    /// Each dot is described as a view of its own and built from the supplied
    /// content closure.
    ///
    ///     IndicatorView(cards) { _ in
    ///         Image("diamond.png")
    ///     }
    ///     .position(shown)
    ///
    /// The items take the place of `count`, which is derived from them.
    public init<Items: RandomAccessCollection>(
        _ items: Items,
        content: (Items.Element) -> Element
    ) {
        node = Node(type: .indicatorView, children: items.map { content($0).body })
    }

}

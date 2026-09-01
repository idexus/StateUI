// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: IndicatorView.

/// IndicatorView's own properties - the half a `Style<IndicatorView>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol IndicatorViewProperties: PropertyContainer {}

extension IndicatorViewProperties {
    /// How many dots there are. MAUI: IndicatorView.Count.
    ///
    /// The other way to say it is `IndicatorView(items) { … }`, which MAUI
    /// counts for itself - one or the other, never both.
    public func count(_ value: Int) -> Modified {
        setValue(.count, .number(Double(value)))
    }

    /// Which one is the current one, counting from 0.
    /// MAUI: IndicatorView.Position.
    ///
    /// Told to it rather than read from it: nothing about an IndicatorView is
    /// the reader's to change, so there is no binding overload here - a
    /// gallery's `position($shown)` is what writes, and this reads the same
    /// state.
    public func position(_ value: Int) -> Modified {
        setValue(.position, .number(Double(value)))
    }

    /// The colour of a dot that is not the current one.
    /// MAUI: IndicatorView.IndicatorColor.
    public func indicatorColor(_ value: Color) -> Modified {
        setValue(.indicatorColor, value.propValue)
    }

    /// And of the one that is. MAUI: IndicatorView.SelectedIndicatorColor.
    public func selectedIndicatorColor(_ value: Color) -> Modified {
        setValue(.selectedIndicatorColor, value.propValue)
    }

    /// How big each dot is, in device units. MAUI: IndicatorView.IndicatorSize.
    public func indicatorSize(_ value: Double) -> Modified {
        setValue(.indicatorSize, .number(value))
    }

    /// The most dots to draw, however many items there are.
    /// MAUI: IndicatorView.MaximumVisible.
    public func maximumVisible(_ value: Int) -> Modified {
        setValue(.maximumVisible, .number(Double(value)))
    }

    /// A dot or a square. MAUI: IndicatorView.IndicatorsShape - the property
    /// name really is plural, and the enum is not.
    public func indicatorsShape(_ value: IndicatorShape) -> Modified {
        setValue(.indicatorsShape, value.propValue)
    }

    /// Whether one lonely dot is hidden rather than drawn.
    /// MAUI: IndicatorView.HideSingle. True by default, in MAUI as here.
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

    /// Each dot described as a view of its own - MAUI's IndicatorTemplate,
    /// run here rather than bound, the way a CollectionView's rows are.
    ///
    ///     IndicatorView(cards) { _ in
    ///         Image("diamond.png")
    ///     }
    ///     .position(shown)
    ///
    /// The items take the place of `count` - MAUI derives it from them.
    ///
    /// **The platforms disagree about the template, measured.** ANDROID draws
    /// the described dots and still paints the two dot colours BEHIND them, so
    /// the current one wears the selected colour as its background. iOS and Mac
    /// Catalyst draw MAUI's own dots only, and the template never reaches the
    /// screen there.
    public init<Items: RandomAccessCollection>(
        _ items: Items,
        content: (Items.Element) -> Element
    ) {
        node = Node(type: .indicatorView, children: items.map { content($0).body })
    }

}

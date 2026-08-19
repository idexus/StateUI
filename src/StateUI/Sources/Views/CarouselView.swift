// MAUI: CarouselView.

/// CarouselView's own properties - the half a `Style<CarouselView>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol CarouselViewProperties: PropertyContainer {}

extension CarouselViewProperties {
    /// Which item is shown, counting from 0. MAUI: CarouselView.Position.
    ///
    /// One-way: assigning it moves the carousel, and a swipe by the reader goes
    /// nowhere without `.onPositionChanged`. `.position($shown)` on the control
    /// is the two-way form and is what most authors want.
    public func position(_ value: Int) -> Modified {
        setValue(.position, .number(Double(value)))
    }

    /// Whether swiping past the last item comes back to the first.
    /// MAUI: CarouselView.Loop. On by default, in MAUI as here.
    public func loop(_ value: Bool) -> Modified { setValue(.loop, .bool(value)) }

    /// Whether a swipe past the end springs back.
    /// MAUI: CarouselView.IsBounceEnabled.
    public func isBounceEnabled(_ value: Bool) -> Modified {
        setValue(.isBounceEnabled, .bool(value))
    }

    /// Whether moving to another item is animated.
    /// MAUI: CarouselView.IsScrollAnimated.
    public func isScrollAnimated(_ value: Bool) -> Modified {
        setValue(.isScrollAnimated, .bool(value))
    }

    /// Whether the reader may swipe at all. MAUI: CarouselView.IsSwipeEnabled.
    public func isSwipeEnabled(_ value: Bool) -> Modified {
        setValue(.isSwipeEnabled, .bool(value))
    }

    /// How much room is left for the items either side of the current one, in
    /// device units. MAUI: CarouselView.PeekAreaInsets.
    ///
    ///     .peekAreaInsets(Thickness(40))
    ///
    /// The current item narrows by that much, and the neighbours show through
    /// the gap - the usual hint that there is more to swipe to. Zero, MAUI's
    /// own default, gives each item the whole width.
    public func peekAreaInsets(_ value: Thickness) -> Modified {
        setValue(.peekAreaInsets, value.propValue)
    }

    /// Which way it runs. MAUI: CarouselView.ItemsLayout, which is a
    /// LinearItemsLayout - a carousel shows one item at a time, so a grid is not
    /// one of the choices and `.verticalGrid`/`.horizontalGrid` are ignored.
    public func itemsLayout(_ value: ItemsLayout) -> Modified {
        setValue(.itemsLayout, value.propValue)
    }

    /// When the vertical scroll bar is shown - always, never, or as the
    /// platform sees fit. MAUI: ItemsView.VerticalScrollBarVisibility.
    public func verticalScrollBarVisibility(_ value: ScrollBarVisibility) -> Modified {
        setValue(.verticalScrollBarVisibility, value.propValue)
    }

    /// The same, sideways - which is the axis a carousel swipes along unless
    /// `.itemsLayout` says otherwise, so this is usually the one that matters.
    /// MAUI: ItemsView.HorizontalScrollBarVisibility.
    public func horizontalScrollBarVisibility(_ value: ScrollBarVisibility) -> Modified {
        setValue(.horizontalScrollBarVisibility, value.propValue)
    }
}

/// One item at a time, swiped through sideways.
///
///     @State private var shown = 0
///     …
///     CarouselView {
///         ForEach(cards, id: \.id) { card in
///             CardView(card)
///         }
///     }
///     .position($shown)
///     .loop(false)
///     .peekAreaInsets(Thickness(40))
///
/// The children ARE the items, described here like any other views: there is no
/// ItemsSource, no DataTemplate and no binding context, because the Swift side
/// already declared each one. `ForEach` rather than a plain `for` - a card that
/// keeps its item's identity keeps its control when the collection changes.
///
/// Every child is described on every render, however many there are, so this is
/// for a handful of pages. A long collection is a `LazyList`, which describes
/// only the rows in view.
///
/// **An IndicatorView is joined to one by a shared binding, not by naming it.**
/// MAUI's `CarouselView.IndicatorView` points at the other control, and a
/// property that names a control needs a registry this side does not have. Both
/// take a `position`, so one `@State` does the same work:
///
///     CarouselView { … }.position($shown)
///     IndicatorView().count(cards.count).position(shown)
public struct CarouselView: View, CarouselViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<CarouselView>` is written against.
    public init() {
        node = Node(type: .carouselView)
    }

    /// A carousel of whatever the closure describes - one child per item.
    ///
    ///     CarouselView {
    ///         ForEach(cards, id: \.id) { card in
    ///             CardView(card)
    ///         }
    ///     }
    ///
    /// `ForEach` gives each child its item's identity, which is what keeps a
    /// card matched to itself when the collection gains or loses one.
    public init(@ViewBuilder content: () -> [Element]) {
        node = Node(type: .carouselView, children: content().map { $0.body })
    }

    /// The same, two-way: swiping to another item writes the new one back.
    ///
    ///     CarouselView { … }.position($shown)
    public func position(_ binding: Binding<Int>) -> Self {
        position(binding.wrappedValue)
            .addHandler(.positionChanged) {
                if let position = EventBuffer.current.value()?.int {
                    binding.wrappedValue = position
                }
            }
    }

    /// Another item came into view, and this is which one.
    /// MAUI: CarouselView.PositionChanged.
    ///
    /// MAUI's `CurrentItemChanged` carries the ITEM, which on this side is a
    /// view the Swift code already has - so the position is what crosses, and it
    /// is the half that means anything here.
    ///
    /// Runs in WRITING order with a binding's write: written after
    /// `.position($:)` it sees the state already updated, written before it
    /// the state still holds the old position - the payload carries the new
    /// one either way.
    public func onPositionChanged(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        addHandler(.positionChanged) {
            if let position = EventBuffer.current.value()?.int {
                try await handler(position)
            }
        }
    }

    /// What the carousel shows while it has no items at all.
    /// MAUI: ItemsView.EmptyView.
    ///
    ///     CarouselView { … }
    ///         .emptyView(Label("Nothing to leaf through"))
    public func emptyView(_ view: Element) -> Self {
        var copy = self

        // A slot, not an item: a child of a type the renderer reads by name,
        // appended after every page - the rule a LazyList's furniture
        // follows, one control over.
        copy.node.children.removeAll { $0.type == .emptyView }
        copy.node.children.append(Node(type: .emptyView, children: [view.body]))

        return copy
    }
}

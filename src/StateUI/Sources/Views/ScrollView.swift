// MAUI: ScrollView.

/// ScrollView's own properties - the half a `Style<ScrollView>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol ScrollViewProperties: PropertyContainer {}

extension ScrollViewProperties {
    /// Which way it scrolls, if not down. MAUI: ScrollView.Orientation, whose
    /// default is `.vertical`.
    ///
    /// `.horizontal` is the row of cards; `.both` is the drawing canvas; and
    /// `.neither` is how a scroller is stopped from scrolling without being
    /// taken out of the tree.
    public func orientation(_ value: ScrollOrientation) -> Modified {
        setValue(.orientation, value.propValue)
    }

    /// Whether the bar down the side is drawn.
    /// MAUI: ScrollView.VerticalScrollBarVisibility.
    ///
    /// `.never` is what a scroller inside a page of cards usually wants - the
    /// bar says the same thing the content already does. MAUI declares this on
    /// ScrollView and again on ItemsView, which is why a `CarouselView` carries
    /// its own.
    public func verticalScrollBarVisibility(_ value: ScrollBarVisibility) -> Modified {
        setValue(.verticalScrollBarVisibility, value.propValue)
    }

    /// The same, along the bottom.
    /// MAUI: ScrollView.HorizontalScrollBarVisibility.
    public func horizontalScrollBarVisibility(_ value: ScrollBarVisibility) -> Modified {
        setValue(.horizontalScrollBarVisibility, value.propValue)
    }
}

/// A scrollable container. MAUI: ScrollView.
///
///     ScrollView {
///         VStack { … }
///     }
///     .verticalScrollBarVisibility(.never)
///
/// MAUI's ScrollView holds a single view in its Content. Several children are
/// wrapped in a VerticalStackLayout by the renderer rather than all but the
/// first being dropped.
///
/// `.padding` is inside the scroller and moves with the content; `.margin` is
/// outside it and stays put. For a long list of rows built from data, reach
/// for `LazyList` instead - a ScrollView describes every child it holds,
/// whether or not any of them can be seen.
public struct ScrollView: View, PaddingElement, ScrollViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ScrollView>` is written against.
    public init() {
        node = Node(type: .scrollView)
    }

    /// A scrollable view around what the closure describes.
    public init(@ViewBuilder content: () -> [Element]) {
        node = Node(type: .scrollView, children: content().map { $0.body })
    }

    /// How far down it has been scrolled, in device units.
    /// MAUI: ScrollView.ScrollY, which is read-only - so this only writes INTO
    /// the binding and never moves the scroller.
    ///
    ///     @State private var offset = 0.0
    ///
    ///     ScrollView { VStack { … } }.scrollY($offset)
    ///     Label("\(Int(offset)) down")
    ///
    /// Moving it is `scrollTo(x:y:)` on a `ControlState<ScrollView>` - see the
    /// act at the foot of this file. Each report is a render, so a view that
    /// watches this one redraws all the way down a drag.
    public func scrollY(_ binding: Binding<Double>) -> Self {
        addHandler(.scrollYChanged) {
            if let offset = EventBuffer.current.value()?.number {
                binding.wrappedValue = offset
            }
        }
    }

    /// The same, sideways - and read-only in the same way.
    /// MAUI: ScrollView.ScrollX.
    public func scrollX(_ binding: Binding<Double>) -> Self {
        addHandler(.scrollXChanged) {
            if let offset = EventBuffer.current.value()?.number {
                binding.wrappedValue = offset
            }
        }
    }
}

// MARK: - The acts

extension ControlState where Target == ScrollView {
    /// Scrolls to an offset, in device units from the content's top-left
    /// corner - the other direction of the `scrollY($:)` report. MAUI:
    /// ScrollView.ScrollToAsync, the `Async` dropped because `await` at the
    /// call site already says it.
    ///
    ///     @State private var scroller = ControlState<ScrollView>()
    ///
    ///     ScrollView { … }.assign(scroller).scrollY($offset)
    ///
    ///     Button("Back to top")
    ///         .onClicked { try await scroller.scrollTo(x: 0, y: 0) }
    ///
    /// The answer arrives when the scroll has FINISHED, so an animated one
    /// suspends the handler for its whole glide - and on a view that is not
    /// on screen it does nothing and reports done, the way an animation does.
    ///
    /// - Parameters:
    ///   - x: how far in from the left, in device units.
    ///   - y: how far down from the top.
    ///   - animated: whether the platform glides there or jumps.
    /// - Throws: `StateUIError` when the state reached no `.assign()` or two
    ///   of them, when no view of that id is being shown, or when the view it
    ///   names is not a ScrollView.
    public nonisolated(nonsending) func scrollTo(
        x: Double,
        y: Double,
        animated: Bool = true
    ) async throws {
        try await stateUICall(
            .scrollToAsync,
            [try target, .number(x), .number(y), .bool(animated)])
    }
}

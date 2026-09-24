// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `ScrollView`'s own properties, shared by the control and its
/// `Style<ScrollView>`.
public protocol ScrollViewProperties: PropertyContainer {}

extension ScrollViewProperties {
    /// Which way it scrolls, if not down. The default is `.vertical`.
    ///
    /// `.neither` is for a scroller with nothing to scroll, such as an emptied
    /// list: it goes back to the beginning. To stop the user's hand and leave
    /// the scroller where it stands, write `.ignoresInput(true)` instead.
    public func orientation(_ value: ScrollOrientation) -> Modified {
        setValue(ScrollViewContract.orientation, value)
    }

    /// Whether the bar down the side is drawn.
    ///
    /// `.never` is what a scroller inside a page of cards usually wants - the
    /// bar says the same thing the content already does.
    public func verticalScrollBarVisibility(_ value: ScrollBarVisibility) -> Modified {
        setValue(ScrollViewContract.verticalScrollBarVisibility, value)
    }

    /// The same, along the bottom.
    public func horizontalScrollBarVisibility(_ value: ScrollBarVisibility) -> Modified {
        setValue(ScrollViewContract.horizontalScrollBarVisibility, value)
    }
}

/// A scrollable container.
///
///     ScrollView {
///         VStack { … }
///     }
///     .verticalScrollBarVisibility(.never)
///
/// `.padding` is inside the scroller and moves with the content; `.margin` is
/// outside it and stays put. A ScrollView describes every child it holds,
/// whether or not any of them can be seen.
///
/// When a one-axis scroller is nested in another, it owns gestures along its
/// axis and passes a dominant gesture on the disabled axis to the enclosing
/// scroller. A horizontal code listing can therefore live inside a vertical
/// page without interrupting the page's movement.
public struct ScrollView: View, PaddingElement, BorderElement, ScrollViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ScrollView>` is written against.
    public init() {
        node = Node(contract: ScrollViewContract.self)
    }

    /// A scrollable view around what the closure describes. The closure runs
    /// when the differ reaches the scroller.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(contract: ScrollViewContract.self)
        node.producer = { content().map { $0.body } }
    }

    /// Where the scroller stands, in device units from the content's top-left
    /// corner, both ways: the host writes the user's scrolling into the state,
    /// and a value written there moves the scroller.
    ///
    ///     @State private var offset = Point.zero
    ///
    ///     ScrollView { VStack { … } }.scrollOffset($offset)
    ///
    ///     Button("Top").onClicked { offset = .zero }
    ///
    /// `offset` is where it is going and `$offset.journey.value` where it is. A
    /// write animates under the element's motion, `$offset.journey.snap(to:)`
    /// jumps, and `try await $offset.journey.move(to:)` waits for the arrival.
    /// Handing `$offset` over reads nothing: a body that reads `offset` renders
    /// on every report, and `.samples($offset, into:, .every(100))` holds a
    /// reading to ten a second.
    ///
    /// - Parameter state: the state the offset is carried on.
    /// - Returns: the scroller, moving with that state and reporting into it.
    public func scrollOffset(_ state: Binding<Point>) -> Self {
        journey(.scrollOffset, by: state)
    }

    /// Runs once the scroller has come to rest: nothing is moving and no finger
    /// is on it.
    ///
    ///     ScrollView { … }.onScrollStopped { load() }
    ///
    /// The moment for work that would show as a hitch during a swipe, and for
    /// carrying the scroller on to the nearest item by writing the offset. It
    /// runs once per movement the user makes - a drag let go, a throw that ran
    /// out, a wheel, a key - and not for one that leaves the offset where it
    /// was, nor for one the application wrote.
    public func onScrollStopped(_ handler: @escaping EventHandler) -> Self {
        onEvent(ScrollViewContract.scrollStopped, handler)
    }
}

extension ScrollView {
    /// `horizontalScrollBarVisibility` from a state, `$x`: the host sets each
    /// new value as it stands, and no view is rebuilt for it.
    public func horizontalScrollBarVisibility(_ state: Binding<ScrollBarVisibility>) -> Modified {
        plain(.horizontalScrollBarVisibility, by: state)
    }

    /// `orientation` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func orientation(_ state: Binding<ScrollOrientation>) -> Modified {
        plain(.orientation, by: state)
    }

    /// `verticalScrollBarVisibility` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func verticalScrollBarVisibility(_ state: Binding<ScrollBarVisibility>) -> Modified {
        plain(.verticalScrollBarVisibility, by: state)
    }
}

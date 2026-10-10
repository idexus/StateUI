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
    public func verticalScrollIndicator(_ value: ScrollIndicatorVisibility) -> Modified {
        setValue(ScrollViewContract.verticalScrollIndicator, value)
    }

    /// The same, along the bottom.
    public func horizontalScrollIndicator(_ value: ScrollIndicatorVisibility) -> Modified {
        setValue(ScrollViewContract.horizontalScrollIndicator, value)
    }
}

/// A scrollable container.
///
///     ScrollView {
///         VStack { … }
///     }
///     .verticalScrollIndicator(.never)
///
/// `.padding` is inside the scroller and moves with the content; `.margin` is
/// outside it and stays put. A ScrollView describes every child it holds,
/// whether or not any of them can be seen.
///
/// When a one-axis scroller is nested in another, it owns gestures along its
/// axis and passes a dominant gesture on the disabled axis to the enclosing
/// scroller. A horizontal code listing can therefore live inside a vertical
/// page without interrupting the page's movement.
public struct ScrollView: ElementView, PaddingElement, BorderElement, ScrollViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ScrollView>` is written against.
    public init() {
        node = Node(contract: ScrollViewContract.self)
    }

    /// A scrollable view around what the closure describes. The closure runs
    /// when the differ reaches the scroller.
    public init<Content: Views>(@ViewBuilder content: @escaping () -> Content) {
        node = Node(contract: ScrollViewContract.self)
        node.producer = { content().nodes }
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
    /// jumps, and `$offset.journey.move(to:)` animates under a law of its own.
    /// Handing `$offset` over reads nothing: a body that reads `offset` renders
    /// on every report, and `.samples($offset, into: $shown, .every(100))`
    /// holds a reading to ten a second.
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
    public func onScrollStopped(_ handler: @escaping @MainActor () throws -> Void) -> Self {
        onEvent(ScrollViewContract.scrollStopped, handler)
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onScrollStopped(gate: some Gate, _ handler: @escaping EventHandler) -> Self {
        onEvent(ScrollViewContract.scrollStopped, gate: gate, handler)
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onScrollStopped(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onScrollStopped(_ handler: @escaping EventHandler) -> Self {
        fatalError("unavailable")
    }
}

extension ScrollView {
    /// `horizontalScrollIndicator` from a state, `$x`: the host sets each
    /// new value as it stands, and no view is rebuilt for it.
    public func horizontalScrollIndicator(_ state: Binding<ScrollIndicatorVisibility>) -> Modified {
        plain(.horizontalScrollIndicator, by: state)
    }

    /// `orientation` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func orientation(_ state: Binding<ScrollOrientation>) -> Modified {
        plain(.orientation, by: state)
    }

    /// `verticalScrollIndicator` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func verticalScrollIndicator(_ state: Binding<ScrollIndicatorVisibility>) -> Modified {
        plain(.verticalScrollIndicator, by: state)
    }
}

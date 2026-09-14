// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// ScrollView's own properties - the half a `Style<ScrollView>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol ScrollViewProperties: PropertyContainer {}

extension ScrollViewProperties {
    /// Which way it scrolls, if not down. The default is `.vertical`.
    ///
    /// `.horizontal` is the row of cards; `.both` is the drawing canvas; and
    /// `.neither` is for a scroller with NOTHING to scroll - an emptied list.
    /// Told that, a scroller goes back to the beginning and cannot be moved
    /// again from either side - so one merely being stopped under the reader
    /// keeps its way and says `.ignoresInput(true)` instead, which stops
    /// the hand and leaves the scroller where it stands.
    public func orientation(_ value: ScrollOrientation) -> Modified {
        setValue(.orientation, value.propValue)
    }

    /// Whether the bar down the side is drawn.
    ///
    /// `.never` is what a scroller inside a page of cards usually wants - the
    /// bar says the same thing the content already does.
    public func verticalScrollBarVisibility(_ value: ScrollBarVisibility) -> Modified {
        setValue(.verticalScrollBarVisibility, value.propValue)
    }

    /// The same, along the bottom.
    public func horizontalScrollBarVisibility(_ value: ScrollBarVisibility) -> Modified {
        setValue(.horizontalScrollBarVisibility, value.propValue)
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
public struct ScrollView: View, PaddingElement, ScrollViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ScrollView>` is written against.
    public init() {
        node = Node(type: .scrollView)
    }

    /// A scrollable view around what the closure describes.
    /// The closure is kept and run when the differ describes the scroller.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(type: .scrollView)
        node.producer = { content().map { $0.body } }
    }

    /// Where the scroller stands, in device units from the content's top-left
    /// corner - BOTH WAYS. The host writes the reader's own scrolling into it
    /// on its own frames, and a value written here MOVES the scroller, every
    /// frame made by this side's engine on the display's clock.
    ///
    ///     @State private var offset = Point.zero
    ///
    ///     ScrollView { VStack { … } }.scrollOffset($offset)
    ///
    ///     Button("Top").onClicked { offset = .zero }
    ///
    /// ONE POINT RATHER THAN TWO NUMBERS: the platform's offset is one point
    /// and the engine moves it as one, so a diagonal move arrives on both axes
    /// together instead of as two walks ending whenever each of them ends.
    ///
    /// `offset` is where it is GOING and `$offset.journey.value` where it IS -
    /// what the reader is looking at. A write travels under the element's
    /// law, `$offset.journey.snap(to: )` puts it there at once, and
    /// `try await $offset.journey.move(to: )` waits for the arrival. A report
    /// from the reader's own finger lands on both together, so nothing is
    /// aimed out from under the hand holding it.
    ///
    /// Handing `$offset` over reads nothing at build, so the scroller is no
    /// reader of it, and what the offset COSTS is decided by who reads it.
    /// Read at no build - followed by an engine, driving a text, placing a run
    /// of views - it moves for no render at all. Read in a body
    /// (`Label("\(Int(offset.y)) down")`) it renders that body on every
    /// report the reader's hand makes, and `$offset.journey.value` there
    /// renders it on every frame; `.samples($offset, into:, .every(100))`
    /// holds a reading to ten a second.
    ///
    /// - Parameter state: the state the offset is walked on.
    /// - Returns: the scroller, moving with that state and reporting into it.
    public func scrollOffset(_ state: Binding<Point>) -> Self {
        journey(.scrollOffset, by: state)
    }

    /// Runs once the scroller has come to REST: nothing is moving, no finger
    /// is on it, and where it stands is where it stays. This library's own.
    ///
    ///     ScrollView { … }.onScrollStopped { load() }
    ///
    /// This is the moment when work that would be SEEN as a hitch costs
    /// nothing, which is what it is for: a list widens the run of rows it
    /// describes here rather than while a swipe is under way. Nothing
    /// waits for the answer - it says what has already happened - so a handler
    /// here can take as long as the work does.
    ///
    /// Once per movement of the READER's, whichever kind ended it: a drag let
    /// go of, a throw that ran out, a wheel, a key. A movement that leaves the
    /// offset exactly where it was reports nothing, and so does one the
    /// application wrote: it knows where it sent the scroller, and
    /// `try await $offset.journey.move(to:)` waits for it to arrive. The reader
    /// taking hold stops such a movement where it stands.
    ///
    /// It is also where a scroller is brought to rest on something of the
    /// author's own. The platform's own throw stops wherever it stops, and a
    /// write to the offset from here carries the scroller on to the item it is
    /// nearest - which is how `GalleryView` settles on a card.
    public func onScrollStopped(_ handler: @escaping EventHandler) -> Self {
        addHandler(.scrollStopped, handler)
    }
}

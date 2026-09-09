// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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
    /// `.neither` is for a scroller with NOTHING to scroll - an emptied list.
    /// Told that, a scroller goes back to the beginning and cannot be moved
    /// again from either side - so one merely being stopped under the reader
    /// keeps its way and says `.inputTransparent(true)` instead, which stops
    /// the hand and leaves the scroller where it stands.
    public func orientation(_ value: ScrollOrientation) -> Modified {
        setValue(.orientation, value.propValue)
    }

    /// Whether the bar down the side is drawn.
    /// MAUI: ScrollView.VerticalScrollBarVisibility.
    ///
    /// `.never` is what a scroller inside a page of cards usually wants - the
    /// bar says the same thing the content already does. MAUI declares this on
    /// ScrollView and again on ItemsView, which is why an items control
    /// carries its own.
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
public struct ScrollView: View, PaddingElement, DeferredContent, ScrollViewProperties {
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
    ///     @State private var offset = MotionChannel(Point.zero)
    ///
    ///     ScrollView { VStack { … } }.scroll($offset)
    ///
    ///     Button("Top").onClicked { offset.setPoint = .zero }
    ///
    /// ONE POINT RATHER THAN TWO NUMBERS: the platform's offset is one point
    /// and the engine moves it as one, so a diagonal move arrives on both axes
    /// together instead of as two walks ending whenever each of them ends.
    ///
    /// `offset.value` is where it IS - what the reader is looking at - and
    /// `offset.setPoint` where it is going. A write travels under the
    /// element's law, `$offset.snap(to: )` puts it there at once, and
    /// `try await $offset.animateTo(_: )` waits for the arrival. A report from
    /// the reader's own finger lands on both together, so nothing is aimed out
    /// from under the hand holding it.
    ///
    /// Handing `$offset` over reads nothing at build, so the scroller is no
    /// reader of it, and what the offset COSTS is decided by who reads it.
    /// Read at no build - followed by an engine, driving a text, placing a run
    /// of views - it moves for no render at all. Read in a body
    /// (`Label("\(Int(offset.value.y)) down")`) it renders that body on every
    /// report, or at most once a window where the state says
    /// `@State(asks: .every(100))`.
    ///
    /// - Parameter state: the state the offset is walked on.
    /// - Returns: the scroller, moving with that state and reporting into it.
    public func scroll(_ state: Binding<Point>) -> Self {
        journey(.scroll, by: state)
    }

    /// Makes the scroller come to rest on a GRID: the offsets it may stop at
    /// are `from`, `from + value`, `from + 2 * value`, and so on, in device
    /// units. This library's own.
    ///
    ///     ScrollView { … }.orientation(.horizontal).snapInterval(160)
    ///
    /// The moment a finger lifts, where the platform's own deceleration WOULD
    /// have stopped is rounded to the nearest point of the grid - so a throw
    /// lands as far along as its speed deserves, and it is ONE movement with
    /// nothing waiting for this side to answer.
    ///
    /// WHICH MOVEMENT depends on how far that was going, counted in points of
    /// the grid. A release crossing MORE than one point keeps the platform's own
    /// curve and is simply sent to the rounded point. A release crossing one or
    /// none is made here instead, in two parts: the distance STILL TO GO at one
    /// point of the grid every 0.3 seconds, plus a fifth of a second of landing
    /// that every movement ends with however short it was. A whole point
    /// therefore takes half a second and a tenth of one a shade over two
    /// hundred milliseconds - starting further means starting faster, and every
    /// settle arrives the same way. It is made here because a platform sent
    /// somewhere its own throw was
    /// not going stretches its deceleration to arrive there, and stretches it
    /// further the more gently the reader let go: the same half-card then takes
    /// a moment after a flick and the better part of a second after a nudge.
    /// At a stated speed half a card simply takes half as long as a whole one.
    ///
    /// A scroller left to rest between two points anyway - by a platform that
    /// will not be told, or by a wheel no gesture preceded - is taken to the
    /// nearest one when it stops, at that same speed.
    ///
    /// `.snapItem($:)` is the other half: which point of the grid it is
    /// nearest, reported as that changes. `GalleryView` is the pair of them
    /// over a card and its gap.
    ///
    /// - Parameters:
    ///   - value: how far apart the offsets it may rest on are. Zero is a
    ///     scroller that rests wherever the platform leaves it.
    ///   - from: where the grid starts, in device units. Nothing, for a grid
    ///     that starts at the content's own beginning - which is what a run
    ///     of cards padded at each end wants, its first card being centred at
    ///     an offset of zero.
    public func snapInterval(_ value: Double, from: Double = 0) -> Self {
        var copy = self
        copy.node.props[.snapInterval] = .number(max(0, value))
        copy.node.props[.snapFrom] = .number(from)
        return copy
    }

    /// The most points of the grid one release may cross. Nothing is the
    /// default, and means as many as the throw carries. This library's own.
    ///
    ///     ScrollView { … }.snapInterval(320).snapsAtMost(1)
    ///
    /// A hard throw on a grid of cards lands several cards on, which is right
    /// for a strip somebody is looking THROUGH and wrong for one they are
    /// stepping through: `1` makes every swipe move exactly one card, however
    /// hard it was thrown, and the card still arrives with the settle any other
    /// swipe gets.
    ///
    /// It is measured from where the FINGER LANDED rather than from where it let
    /// go, so a drag most of the way to the next card and a throw on the end of
    /// it cannot add up to two. Without a `.snapInterval` there are no points to
    /// count and this does nothing.
    ///
    /// - Parameter points: how many points of the grid a release may cross.
    ///   Zero, or less, is no limit.
    public func snapsAtMost(_ points: Int) -> Self {
        setValue(.snapsAtMost, .number(Double(max(0, points))))
    }

    /// How far a released scroll CARRIES, as a fraction of what the platform
    /// would do on its own. 1 is the platform's own throw, and its default.
    /// This library's own.
    ///
    ///     ScrollView { … }.snapInterval(320).momentum(0.5)
    ///
    /// A touch platform throws a scroller a long way - that is what makes a
    /// long list quick to cross - and a strip of CARDS usually wants less of
    /// it: the same flick then means the next card rather than the fourth.
    /// Below 1 the throw is shortened, 0 stops it where the finger left it, and
    /// above 1 it carries further.
    ///
    /// It scales what the PLATFORM predicted rather than replacing it, so a hard
    /// throw still goes further than a gentle one. With a `.snapInterval` the
    /// shortened point is then rounded to the grid, which is what a run of
    /// cards does.
    ///
    /// A scroller that asks for the whole throw and no grid is left entirely
    /// alone with the platform's own physics.
    public func momentum(_ fraction: Double) -> Self {
        setValue(.scrollMomentum, .number(max(0, fraction)))
    }

    /// Which point of the `.snapInterval` grid the scroller is nearest,
    /// counting from 0 - written into the binding as it changes. This
    /// library's own.
    ///
    ///     @State private var card = 0
    ///
    ///     ScrollView { … }.snapInterval(320).snapItem($card)
    ///
    /// It changes as the offset passes the HALFWAY point between two of them,
    /// which is the same rounding that chose where to land - so this always
    /// names the point the scroller is going to stop at, and it names it while
    /// the movement is still under way. That is what makes a card's worth of
    /// scrolling one message and one render, rather than one per frame.
    ///
    /// Read-only, like the offset: moving the scroller is a write to `scroll($:)`.
    /// The grid runs along the way the scroller scrolls - `.vertical` reads
    /// the offset down, everything else the offset across.
    public func snapItem(_ binding: Binding<Int>) -> Self {
        addHandler(.snapItemChanged) {
            if let item = EventBuffer.current.value()?.number {
                binding.wrappedValue = Int(item)
            }
        }
    }

    /// Runs once the scroller has come to REST: nothing is moving, no finger
    /// is on it, and where it stands is where it stays. This library's own.
    ///
    ///     ScrollView { … }.snapInterval(320).onScrollStopped { load() }
    ///
    /// This is the moment when work that would be SEEN as a hitch costs
    /// nothing, which is what it is for: a list widens the run of rows it
    /// describes here rather than while a swipe is under way. Nothing
    /// waits for the answer - it says what has already happened - so a handler
    /// here can take as long as the work does.
    ///
    /// Once per movement, whichever kind ended it: a drag let go of, a throw
    /// that ran out, a wheel, a key, or a write to `scroll($:)`. A scroller that
    /// has to be put back onto its `.snapInterval` grid runs one more short
    /// movement first and this speaks after THAT, so the offset it reports at
    /// is the one the scroller keeps. A movement that leaves the offset
    /// exactly where it was reports nothing.
    public func onScrollStopped(_ handler: @escaping EventHandler) -> Self {
        addHandler(.scrollStopped, handler)
    }
}

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
/// for `CollectionView` instead - a ScrollView describes every child it holds,
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
    /// watches this one redraws all the way down a drag - unless a STEP is
    /// given: `.scrollY($offset, every: 44)` reports once each time the offset
    /// crosses a multiple of 44, which is what a list of 44-point rows wants
    /// to hear and nothing more. One step per scroller, shared by both axes.
    ///
    /// - Parameters:
    ///   - binding: where the offset is written.
    ///   - step: how far the offset moves between two reports, in device
    ///     units. Left out, every change is reported.
    public func scrollY(_ binding: Binding<Double>, every step: Double? = nil) -> Self {
        stepped(step).addHandler(.scrollYChanged) {
            if let offset = EventBuffer.current.value()?.number {
                binding.wrappedValue = offset
            }
        }
    }

    /// The same, sideways - and read-only in the same way.
    /// MAUI: ScrollView.ScrollX.
    ///
    /// - Parameters:
    ///   - binding: where the offset is written.
    ///   - step: how far the offset moves between two reports, in device
    ///     units. Left out, every change is reported.
    public func scrollX(_ binding: Binding<Double>, every step: Double? = nil) -> Self {
        stepped(step).addHandler(.scrollXChanged) {
            if let offset = EventBuffer.current.value()?.number {
                binding.wrappedValue = offset
            }
        }
    }

    /// Makes the scroller come to rest on a GRID: the offsets it may stop at
    /// are `from`, `from + value`, `from + 2 * value`, and so on, in device
    /// units.
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
    /// nearest, reported as that changes. `CarouselView` is the pair of them
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
    /// default, and means as many as the throw carries.
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
        var copy = self
        copy.node.props[.snapsAtMost] = .number(Double(max(0, points)))
        return copy
    }

    /// How far a released scroll CARRIES, as a fraction of what the platform
    /// would do on its own. 1 is the platform's own throw, and its default.
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
    /// shortened point is then rounded to the grid, which is what a carousel
    /// does.
    ///
    /// A scroller that asks for the whole throw and no grid is left entirely
    /// alone with the platform's own physics.
    public func momentum(_ fraction: Double) -> Self {
        var copy = self
        copy.node.props[.scrollMomentum] = .number(max(0, fraction))
        return copy
    }

    /// Which point of the `.snapInterval` grid the scroller is nearest,
    /// counting from 0 - written into the binding as it changes.
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
    /// Read-only, like the offsets: moving the scroller is `scrollTo(x:y:)`.
    /// The grid runs along the way the scroller scrolls - `.horizontal` reads
    /// the offset across, everything else the offset down.
    public func snapItem(_ binding: Binding<Int>) -> Self {
        addHandler(.snapItemChanged) {
            if let item = EventBuffer.current.value()?.number {
                binding.wrappedValue = Int(item)
            }
        }
    }

    /// Runs once the scroller has come to REST: nothing is moving, no finger
    /// is on it, and where it stands is where it stays.
    ///
    ///     ScrollView { … }.snapInterval(320).onScrollStopped { load() }
    ///
    /// This is the moment when work that would be SEEN as a hitch costs
    /// nothing, which is what it is for: a `CarouselView` widens the run of
    /// cards it describes here rather than while a swipe is under way. Nothing
    /// waits for the answer - it says what has already happened - so a handler
    /// here can take as long as the work does.
    ///
    /// Once per movement, whichever kind ended it: a drag let go of, a throw
    /// that ran out, a wheel, a key, or a `scrollTo(x:y:)`. A scroller that
    /// has to be put back onto its `.snapInterval` grid runs one more short
    /// movement first and this speaks after THAT, so the offset it reports at
    /// is the one the scroller keeps. A movement that leaves the offset
    /// exactly where it was reports nothing.
    public func onScrollStopped(_ handler: @escaping EventHandler) -> Self {
        addHandler(.scrollStopped, handler)
    }

    /// The scroller with its report step written, where one was given.
    private func stepped(_ step: Double?) -> Self {
        guard let step, step > 0 else { return self }

        var copy = self
        copy.node.props[.scrollStep] = .number(step)
        return copy
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

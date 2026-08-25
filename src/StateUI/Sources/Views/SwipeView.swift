// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: SwipeView, SwipeItems and SwipeItem.

/// SwipeView's own properties - the half a `Style<SwipeView>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol SwipeViewProperties: PropertyContainer {}

extension SwipeViewProperties {
    /// How far the view has to travel before the items are revealed, in device
    /// units. MAUI: SwipeView.Threshold.
    public func threshold(_ value: Double) -> Modified {
        setValue(.threshold, .number(value))
    }
}

/// A view with actions hidden behind it, revealed by a swipe.
/// MAUI: SwipeView.
///
///     SwipeView {
///         Border {
///             Label(item).padding(16)
///         }
///     }
///     .rightItems(mode: .execute) {
///         SwipeItem("Delete")
///             .backgroundColor(.firebrick)
///             .onInvoked { items.removeAll { $0 == item } }
///     }
///
/// A row in a list is what this is for: MAUI holds one view and reveals a set of
/// items on each side of it, and `.execute` runs the first item on a full swipe
/// with no tap at all.
///
/// The items are NOT views - a `SwipeItem` is a MenuItem in MAUI, which is a
/// caption, a picture and something to run - so they are written with their own
/// modifiers and go nowhere else in the tree.
public struct SwipeView: View, SwipeViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<SwipeView>` is written against.
    public init() {
        node = Node(type: .swipeView)
    }

    /// A swipeable view around what the closure describes. MAUI's SwipeView
    /// holds ONE view; put a layout in it if there is more than one thing to
    /// show.
    public init(@ViewBuilder content: () -> [Element]) {
        node = Node(type: .swipeView, children: content().map { $0.body })
    }

    // MARK: Properties

    // MARK: The swipe itself
    //
    // Three reports about the SWIPE, where `SwipeItem.onInvoked` is about one
    // item being chosen. A row that has to answer while the finger is still
    // moving - a background that darkens as the items come out - listens here.

    /// The reader has begun swiping. MAUI: SwipeView.SwipeStarted.
    public func onSwipeStarted(_ handler: @escaping ValueEventHandler<SwipeDirection>) -> Self {
        addHandler(.swipeStarted) {
            // A payload that will not read leaves the handler alone, the rule
            // every report carrying a direction follows.
            if let direction = SwipeDirection(EventBuffer.current.value()) {
                try await handler(direction)
            }
        }
    }

    /// The swipe is moving, reported as it goes.
    /// MAUI: SwipeView.SwipeChanging.
    public func onSwipeChanging(_ handler: @escaping ValueEventHandler<SwipeChange>) -> Self {
        addHandler(.swipeChanging) {
            if let change = SwipeChange(EventBuffer.current) {
                try await handler(change)
            }
        }
    }

    /// The finger has been lifted, and the items are either out or back.
    /// MAUI: SwipeView.SwipeEnded.
    public func onSwipeEnded(_ handler: @escaping ValueEventHandler<SwipeEnd>) -> Self {
        addHandler(.swipeEnded) {
            if let end = SwipeEnd(EventBuffer.current) {
                try await handler(end)
            }
        }
    }

    // MARK: The items
    //
    // Four collections, one per side, exactly as MAUI has them. The properties
    // belong to the COLLECTION rather than to an item - MAUI puts Mode and
    // SwipeBehaviorOnInvoked on SwipeItems - so they are parameters here, the
    // same way a gesture's are parameters of the handler that listens for it.

    /// The items revealed by swiping right. MAUI: SwipeView.LeftItems.
    ///
    /// - Parameters:
    ///   - mode: whether the items wait to be tapped or the swipe itself runs
    ///     the first one. MAUI: SwipeItems.Mode.
    ///   - swipeBehaviorOnInvoked: what the open items do once one has run.
    ///     MAUI: SwipeItems.SwipeBehaviorOnInvoked.
    public func leftItems(
        mode: SwipeMode = .reveal,
        swipeBehaviorOnInvoked: SwipeBehaviorOnInvoked = .auto,
        @ViewBuilder _ items: () -> [Element]
    ) -> Self {
        self.items(.left, mode, swipeBehaviorOnInvoked, items)
    }

    /// The items revealed by swiping left - where a delete usually goes.
    /// MAUI: SwipeView.RightItems.
    ///
    /// - Parameters:
    ///   - mode: whether the items wait to be tapped or the swipe itself runs
    ///     the first one. MAUI: SwipeItems.Mode.
    ///   - swipeBehaviorOnInvoked: what the open items do once one has run.
    ///     MAUI: SwipeItems.SwipeBehaviorOnInvoked.
    public func rightItems(
        mode: SwipeMode = .reveal,
        swipeBehaviorOnInvoked: SwipeBehaviorOnInvoked = .auto,
        @ViewBuilder _ items: () -> [Element]
    ) -> Self {
        self.items(.right, mode, swipeBehaviorOnInvoked, items)
    }

    /// The items revealed by swiping down. MAUI: SwipeView.TopItems.
    ///
    /// - Parameters:
    ///   - mode: whether the items wait to be tapped or the swipe itself runs
    ///     the first one. MAUI: SwipeItems.Mode.
    ///   - swipeBehaviorOnInvoked: what the open items do once one has run.
    ///     MAUI: SwipeItems.SwipeBehaviorOnInvoked.
    public func topItems(
        mode: SwipeMode = .reveal,
        swipeBehaviorOnInvoked: SwipeBehaviorOnInvoked = .auto,
        @ViewBuilder _ items: () -> [Element]
    ) -> Self {
        self.items(.top, mode, swipeBehaviorOnInvoked, items)
    }

    /// The items revealed by swiping up. MAUI: SwipeView.BottomItems.
    ///
    /// - Parameters:
    ///   - mode: whether the items wait to be tapped or the swipe itself runs
    ///     the first one. MAUI: SwipeItems.Mode.
    ///   - swipeBehaviorOnInvoked: what the open items do once one has run.
    ///     MAUI: SwipeItems.SwipeBehaviorOnInvoked.
    public func bottomItems(
        mode: SwipeMode = .reveal,
        swipeBehaviorOnInvoked: SwipeBehaviorOnInvoked = .auto,
        @ViewBuilder _ items: () -> [Element]
    ) -> Self {
        self.items(.bottom, mode, swipeBehaviorOnInvoked, items)
    }

    /// One collection, replacing whatever was on that side.
    ///
    /// The side is the one thing on the wire that is not a MAUI property name:
    /// XAML says which collection this is by the element it sits inside
    /// (`<SwipeView.LeftItems>`), and there is no such thing as a node inside a
    /// property here.
    private func items(
        _ side: SwipeSide,
        _ mode: SwipeMode,
        _ swipeBehaviorOnInvoked: SwipeBehaviorOnInvoked,
        _ content: () -> [Element]
    ) -> Self {
        var copy = self

        copy.node.children.removeAll {
            $0.type == .swipeItems && $0.props[.side] == side.propValue
        }

        copy.node.children.append(Node(
            type: .swipeItems,
            props: [
                .side: side.propValue,
                .mode: mode.propValue,
                .swipeBehaviorOnInvoked: swipeBehaviorOnInvoked.propValue,
            ],
            children: content().map { $0.body }))

        return copy
    }
}

/// Which of a SwipeView's four collections a set of items is.
///
/// This library's own numbering, mirrored by `SwiftSwipeSide`: MAUI has four
/// separate properties rather than an enum, XAML naming the collection by the
/// element the items sit inside. A closed vocabulary of four, so it rides the
/// wire as a number like every other.
///
/// NOT `SwipeDirection`'s bits, however tempting: the left items are what a
/// swipe to the RIGHT reveals, so the two vocabularies would agree on every
/// name and disagree on every meaning.
enum SwipeSide: Int32, Sendable {
    /// MAUI: SwipeView.LeftItems.
    case left = 0

    /// MAUI: SwipeView.RightItems.
    case right = 1

    /// MAUI: SwipeView.TopItems.
    case top = 2

    /// MAUI: SwipeView.BottomItems.
    case bottom = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

/// One thing a swipe reveals. MAUI: SwipeItem, which is a MenuItem.
///
///     SwipeItem("Favourite")
///         .iconImageSource("nav_media.png")
///         .backgroundColor(.gold)
///         .onInvoked { favourites.insert(item) }
///
/// Not a view: it has a caption, a picture, a colour behind it and something to
/// run, and no layout of its own. So it takes none of the modifiers a view has,
/// and it belongs inside one of a SwipeView's four collections and nowhere else.
public struct SwipeItem: Element, MenuItemElement {
    /// The node this item describes.
    public var node: Node

    /// An item captioned `text`. Give it an `.onInvoked` - an item that does
    /// nothing is one that looks broken.
    public init(_ text: String) {
        node = Node(type: .swipeItem, props: [.text: .string(text)])
    }

    /// The node this item describes.
    public var body: Node { node }

    // `text`, `iconImageSource`, `isDestructive` and `isEnabled` are MenuItem's
    // and live on MenuItemElement, which this conforms to. What is left here is
    // what a SWIPE item alone has - and `onInvoked`, which is why `onClicked`
    // is not on that protocol.

    /// What is drawn behind it, which is how one item is told from the next.
    /// MAUI: SwipeItem.BackgroundColor.
    public func backgroundColor(_ value: Color) -> Self {
        var copy = self
        copy.node.props[.backgroundColor] = value.propValue
        return copy
    }

    /// Whether it is revealed at all - which is how one item of a set is left
    /// out without the set being written twice. MAUI: SwipeItem.IsVisible.
    public func isVisible(_ value: Bool) -> Self {
        var copy = self
        copy.node.props[.isVisible] = .bool(value)
        return copy
    }

    /// What it does. MAUI: SwipeItem.Invoked, which is what its Command runs.
    /// A second `.onInvoked` runs beside the first, like every typed event
    /// modifier.
    public func onInvoked(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.node.addHandler(.invoked, handler)
        return copy
    }
}

/// One report from a swipe in progress - what `.onSwipeChanging` hands its
/// handler. MAUI: SwipeChangingEventArgs.
public struct SwipeChange: Equatable, Sendable {
    /// Which way the view is being swiped.
    /// MAUI: SwipeChangingEventArgs.SwipeDirection.
    public var direction: SwipeDirection

    /// How far it has travelled, in device units.
    /// MAUI: SwipeChangingEventArgs.Offset.
    ///
    /// Signed: negative while the view moves left, positive while it moves
    /// right, which is MAUI's own reading and is why it is not a distance.
    public var offset: Double

    /// Reads a payload's two values - direction, offset, the order MAUI
    /// declares them. Nil for anything else, so a report that will not read
    /// leaves the handler alone.
    init?(_ payload: [PropValue]) {
        guard let direction = SwipeDirection(payload.value(0)),
              let offset = payload.value(1)?.number else { return nil }

        self.direction = direction
        self.offset = offset
    }
}

/// The end of a swipe - what `.onSwipeEnded` hands its handler.
/// MAUI: SwipeEndedEventArgs.
public struct SwipeEnd: Equatable, Sendable {
    /// Which way it was swiped. MAUI: SwipeEndedEventArgs.SwipeDirection.
    public var direction: SwipeDirection

    /// Whether the items are left showing. MAUI: SwipeEndedEventArgs.IsOpen.
    ///
    /// False for a swipe that did not reach the threshold and sprang back,
    /// which is what tells a half-swipe from a real one.
    public var isOpen: Bool

    /// Reads a payload's two values - direction, isOpen, the order MAUI
    /// declares them.
    init?(_ payload: [PropValue]) {
        guard let direction = SwipeDirection(payload.value(0)),
              let isOpen = payload.value(1)?.bool else { return nil }

        self.direction = direction
        self.isOpen = isOpen
    }
}

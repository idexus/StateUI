// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `SwipeView`'s own properties, shared by the control and its
/// `Style<SwipeView>`.
public protocol SwipeViewProperties: PropertyContainer {}

extension SwipeViewProperties {
    /// How far the view has to travel before the items are revealed, in device
    /// units.
    public func threshold(_ value: Double) -> Modified {
        setValue(SwipeViewContract.threshold, value)
    }
}

/// A view with actions hidden behind it, revealed by a swipe.
///
///     SwipeView {
///         Border {
///             Label(item).padding(16)
///         }
///     }
///     .rightItems(mode: .execute) {
///         SwipeAction("Delete")
///             .background(.firebrick)
///             .onClicked { items.removeAll { $0 == item } }
///     }
///
/// A row in a list is what this is for: it holds one view and reveals a set of
/// items on each side of it, and `.execute` runs the first item on a full swipe
/// with no tap at all.
///
/// The items are not views: a `SwipeAction` is a menu item, with modifiers of
/// its own.
public struct SwipeView: View, SwipeViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<SwipeView>` is written against.
    public init() {
        node = Node(contract: SwipeViewContract.self)
    }

    /// A swipeable view around what the closure describes: one view, so put a
    /// layout in it for more.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(contract: SwipeViewContract.self)
        node.producer = { content().map { $0.body } }
    }

    // MARK: The swipe itself

    /// The user has begun swiping.
    public func onSwipeStarted(_ handler: @escaping ValueEventHandler<SwipeDirection>) -> Self {
        // A report naming more than one direction leaves the handler alone.
        onEvent(SwipeViewContract.swipeStarted) { direction in
            guard direction.isOneDirection else { return }
            try await handler(direction)
        }
    }

    /// The swipe is moving, reported as it goes.
    public func onSwipeChanging(_ handler: @escaping ValueEventHandler<SwipeChange>) -> Self {
        onEvent(SwipeViewContract.swipeChanging) { direction, offset in
            guard direction.isOneDirection else { return }
            try await handler(SwipeChange(direction: direction, offset: offset))
        }
    }

    /// The finger has been lifted, and the items are either out or back.
    public func onSwipeEnded(_ handler: @escaping ValueEventHandler<SwipeEnd>) -> Self {
        onEvent(SwipeViewContract.swipeEnded) { direction, isOpen in
            guard direction.isOneDirection else { return }
            try await handler(SwipeEnd(direction: direction, isOpen: isOpen))
        }
    }

    // MARK: The items

    /// The items revealed by swiping right.
    ///
    /// - Parameters:
    ///   - mode: whether the items wait to be tapped or the swipe itself runs
    ///     the first one.
    ///   - swipeBehaviorOnInvoked: what the open items do once one has run.
    public func leftItems(
        mode: SwipeMode = .reveal,
        swipeBehaviorOnInvoked: SwipeBehaviorOnInvoked = .auto,
        @ViewBuilder _ items: () -> [Element]
    ) -> Self {
        self.items(.left, mode, swipeBehaviorOnInvoked, items)
    }

    /// The items revealed by swiping left - where a delete usually goes.
    ///
    /// - Parameters:
    ///   - mode: whether the items wait to be tapped or the swipe itself runs
    ///     the first one.
    ///   - swipeBehaviorOnInvoked: what the open items do once one has run.
    public func rightItems(
        mode: SwipeMode = .reveal,
        swipeBehaviorOnInvoked: SwipeBehaviorOnInvoked = .auto,
        @ViewBuilder _ items: () -> [Element]
    ) -> Self {
        self.items(.right, mode, swipeBehaviorOnInvoked, items)
    }

    /// The items revealed by swiping down.
    ///
    /// - Parameters:
    ///   - mode: whether the items wait to be tapped or the swipe itself runs
    ///     the first one.
    ///   - swipeBehaviorOnInvoked: what the open items do once one has run.
    public func topItems(
        mode: SwipeMode = .reveal,
        swipeBehaviorOnInvoked: SwipeBehaviorOnInvoked = .auto,
        @ViewBuilder _ items: () -> [Element]
    ) -> Self {
        self.items(.top, mode, swipeBehaviorOnInvoked, items)
    }

    /// The items revealed by swiping up.
    ///
    /// - Parameters:
    ///   - mode: whether the items wait to be tapped or the swipe itself runs
    ///     the first one.
    ///   - swipeBehaviorOnInvoked: what the open items do once one has run.
    public func bottomItems(
        mode: SwipeMode = .reveal,
        swipeBehaviorOnInvoked: SwipeBehaviorOnInvoked = .auto,
        @ViewBuilder _ items: () -> [Element]
    ) -> Self {
        self.items(.bottom, mode, swipeBehaviorOnInvoked, items)
    }

    /// One collection, replacing whatever was on that side: a child node that
    /// says which side it is.
    private func items(
        _ side: SwipeSide,
        _ mode: SwipeMode,
        _ swipeBehaviorOnInvoked: SwipeBehaviorOnInvoked,
        _ content: () -> [Element]
    ) -> Self {
        var copy = self

        copy.node.children.removeAll {
            $0.type == SwipeActionsContract.nodeType && $0.props[SwipeActionsContract.side.token] == side.propValue
        }

        var actions = Node(contract: SwipeActionsContract.self, children: content().map { $0.body })
        actions.write(SwipeActionsContract.side, side)
        actions.write(SwipeActionsContract.mode, mode)
        actions.write(SwipeActionsContract.swipeBehaviorOnInvoked, swipeBehaviorOnInvoked)
        copy.node.children.append(actions)

        return copy
    }
}

/// Which of a SwipeView's four collections a set of items is.
///
/// Not a `SwipeDirection`: the left items are what a swipe to the right
/// reveals.
public enum SwipeSide: Int32, Sendable, HostRepresentable {
    /// What `leftItems` holds - revealed by swiping right.
    case left = 0

    /// What `rightItems` holds - revealed by swiping left.
    case right = 1

    /// What `topItems` holds - revealed by swiping down.
    case top = 2

    /// What `bottomItems` holds - revealed by swiping up.
    case bottom = 3
}

/// One thing a swipe reveals - a menu item.
///
///     SwipeAction("Favourite")
///         .icon("nav_media.png")
///         .background(.gold)
///         .onClicked { favourites.insert(item) }
///
/// Not a view: it belongs inside one of a SwipeView's four collections.
public struct SwipeAction: Element, MenuItemElement {
    /// The node this item describes.
    public var node: Node

    /// An item captioned `text`. Give it an `.onClicked` - an item that does
    /// nothing is one that looks broken.
    public init(_ text: String) {
        node = Node(contract: SwipeActionContract.self)
        node.write(MenuItemElementContract.text, text)
    }

    /// The node this item describes.
    public var body: Node { node }

    /// What is drawn behind it, which is how one item is told from the next.
    public func background(_ value: Color) -> Self {
        setValue(SwipeActionContract.background, value)
    }

    /// Whether it is revealed at all - which is how one item of a set is left
    /// out without the set being written twice.
    public func isVisible(_ value: Bool) -> Self {
        setValue(SwipeActionContract.isVisible, value)
    }
}

/// One report from a swipe in progress - what `.onSwipeChanging` hands its
/// handler.
public struct SwipeChange: Equatable, Sendable {
    /// Which way the view is being swiped.
    public var direction: SwipeDirection

    /// How far it has travelled, in device units.
    ///
    /// Negative while the view moves left, positive while it moves right.
    public var offset: Double
}

/// The end of a swipe - what `.onSwipeEnded` hands its handler.
public struct SwipeEnd: Equatable, Sendable {
    /// Which way it was swiped.
    public var direction: SwipeDirection

    /// Whether the items are left showing.
    ///
    /// False for a swipe that did not reach the threshold and sprang back.
    public var isOpen: Bool
}

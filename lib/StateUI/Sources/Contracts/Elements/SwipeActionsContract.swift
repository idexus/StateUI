// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One of a swipe view's four collections of actions, and what they do.
public enum SwipeActionsContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .swipeActions

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// Whether the actions wait to be tapped, or the swipe itself runs the
    /// first.
    public static let mode = ElementProperty<Self, SwipeMode>("mode", layer: .stateUI)

    /// Which of the four collections it is.
    public static let side = ElementProperty<Self, SwipeSide>("side", layer: .stateUI, cleared: false)

    /// What the open actions do once one has run.
    public static let swipeBehaviorOnInvoked = ElementProperty<Self, SwipeBehaviorOnInvoked>(
        "swipeBehaviorOnInvoked", layer: .stateUI)

    /// The element's own members.
    public static let members: [any ContractMember] = [mode, side, swipeBehaviorOnInvoked]
}

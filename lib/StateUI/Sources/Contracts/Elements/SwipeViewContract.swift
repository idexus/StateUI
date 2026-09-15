// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view with actions hidden behind it, revealed by a swipe.
public enum SwipeViewContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "SwipeView"

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    public static let layer: ElementLayer = .stateUI

    /// A swipeable view is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// The swipe moved: which way, and how far in device units.
    public static let swipeChanging = ElementEvent<Self, (SwipeDirection, Double)>(
        "swipeChanging", layer: .stateUI)

    /// The finger was lifted: which way it swiped, and whether the actions are
    /// left showing.
    public static let swipeEnded = ElementEvent<Self, (SwipeDirection, Bool)>("swipeEnded", layer: .stateUI)

    /// The reader began swiping, in a direction.
    public static let swipeStarted = ElementEvent<Self, SwipeDirection>("swipeStarted", layer: .stateUI)

    /// How far the view travels before the actions are revealed, in device
    /// units.
    public static let threshold = ElementProperty<Self, Double>("threshold", layer: .stateUI)

    /// The element's own members.
    public static let members: [any ContractMember] = [swipeChanging, swipeEnded, swipeStarted, threshold]
}

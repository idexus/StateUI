// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every view a layout positions has: where it sits in its layout, the
/// space kept around it, and the gestures, drags and frame reports it answers.
public enum ViewContract: Contract {
    /// The tier's name.
    public static let name = "View"

    /// Every view is drawn.
    public static let tiers: [any Contract.Type] = [VisualElementContract.self]

    /// Where the view sits in an AbsoluteLayout, and how big it is there.
    public static let absoluteLayoutBounds = ElementProperty<Self, Rect>(
        "absoluteLayoutBounds", layer: .structure, travels: false)

    /// Which parts of those bounds are fractions of the layout.
    public static let absoluteLayoutProportions = ElementProperty<Self, AbsoluteLayoutProportions>(
        "absoluteLayoutProportions", layer: .structure, travels: false)

    /// Whether the view accepts what is dropped on it.
    public static let allowDrop = ElementProperty<Self, Bool>("allowDrop", layer: .native, cleared: false)

    /// Whether the view can be dragged.
    public static let canDrag = ElementProperty<Self, Bool>("canDrag", layer: .native, cleared: false)

    /// A drag left the view without being let go.
    public static let dragLeave = ElementEvent<Self, Void>("dragLeave", layer: .native)

    /// A drag is over the view, not yet let go.
    public static let dragOver = ElementEvent<Self, Void>("dragOver", layer: .native)

    /// A drag of the view is starting.
    public static let dragStarting = ElementEvent<Self, Void>("dragStarting", layer: .native)

    /// The text a drag of the view carries.
    public static let dragText = ElementProperty<Self, String>("dragText", layer: .native, cleared: false)

    /// Something was dropped on the view, with the text it carried.
    public static let drop = ElementEvent<Self, String>("drop", layer: .native)

    /// A drag that started on the view ended, wherever it ended.
    public static let dropCompleted = ElementEvent<Self, Void>("dropCompleted", layer: .native)

    /// The view settled on a frame: eight numbers - x, y, width, height, the
    /// window's x and y, and the safe area's x and y.
    public static let frameChanged = ElementEvent<Self, [Double]>("frameChanged", layer: .native)

    /// Which column of a Grid the view sits in.
    public static let gridColumn = ElementProperty<Self, Int>("gridColumn", layer: .stateUI, travels: false)

    /// How many columns of a Grid the view spans.
    public static let gridColumnSpan = ElementProperty<Self, Int>(
        "gridColumnSpan", layer: .stateUI, travels: false)

    /// Which row of a Grid the view sits in.
    public static let gridRow = ElementProperty<Self, Int>("gridRow", layer: .stateUI, travels: false)

    /// How many rows of a Grid the view spans.
    public static let gridRowSpan = ElementProperty<Self, Int>("gridRowSpan", layer: .stateUI, travels: false)

    /// How the view uses the width its layout offers.
    public static let horizontalAlignment = ElementProperty<Self, Alignment>(
        "horizontalAlignment", layer: .native)

    /// The space kept outside the view, between it and its neighbours.
    public static let margin = ElementProperty<Self, Insets>("margin", layer: .native, moves: .spacing)

    /// How many pointers a pan must have.
    public static let panTouchCount = ElementProperty<Self, Int>(
        "panTouchCount", layer: .structure, travels: false, cleared: false)

    /// The view is being dragged: the phase, and how far across and down since
    /// the pan began.
    public static let panUpdated = ElementEvent<Self, (GesturePhase, Double, Double)>(
        "panUpdated", layer: .native)

    /// The number of the state a drag's distance across is written into.
    public static let panXChannel = ElementProperty<Self, Int>(
        "panXChannel", layer: .structure, travels: false)

    /// The number of the state a drag's distance down is written into.
    public static let panYChannel = ElementProperty<Self, Int>(
        "panYChannel", layer: .structure, travels: false)

    /// Two fingers moved apart or together: the phase, the scale since the
    /// last report, and the pinch's centre as a fraction of the view.
    public static let pinchUpdated = ElementEvent<Self, (GesturePhase, Double, Point)>(
        "pinchUpdated", layer: .native)

    /// A pointer entered the view.
    public static let pointerEntered = ElementEvent<Self, Void>("pointerEntered", layer: .native)

    /// A pointer left the view.
    public static let pointerExited = ElementEvent<Self, Void>("pointerExited", layer: .native)

    /// A pointer moved over the view, where the platform says where.
    public static let pointerMoved = ElementEvent<Self, Point?>("pointerMoved", layer: .native)

    /// A pointer button went down over the view, where the platform says where.
    public static let pointerPressed = ElementEvent<Self, Point?>("pointerPressed", layer: .native)

    /// A pointer button came up over the view, where the platform says where.
    public static let pointerReleased = ElementEvent<Self, Point?>("pointerReleased", layer: .native)

    /// Which ways a swipe on the view is listened for.
    public static let swipeDirection = ElementProperty<Self, SwipeDirection>(
        "swipeDirection", layer: .structure, cleared: false)

    /// How far a finger must travel for a swipe, in device units.
    public static let swipeThreshold = ElementProperty<Self, Double>(
        "swipeThreshold", layer: .structure, travels: false, cleared: false)

    /// The view was swiped, the one dominant direction it went.
    public static let swiped = ElementEvent<Self, SwipeDirection>("swiped", layer: .native)

    /// How many taps in a row a tap on the view takes.
    public static let tapCount = ElementProperty<Self, Int>(
        "tapCount", layer: .structure, travels: false, cleared: false)

    /// The view was tapped.
    public static let tapped = ElementEvent<Self, Void>("tapped", layer: .native)

    /// How the view uses the height its layout offers.
    public static let verticalAlignment = ElementProperty<Self, Alignment>(
        "verticalAlignment", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [
        absoluteLayoutBounds, absoluteLayoutProportions, allowDrop, canDrag, dragLeave,
        dragOver, dragStarting, dragText, drop, dropCompleted, frameChanged, gridColumn,
        gridColumnSpan, gridRow, gridRowSpan, horizontalAlignment, margin, panTouchCount,
        panUpdated, panXChannel, panYChannel, pinchUpdated, pointerEntered, pointerExited,
        pointerMoved, pointerPressed, pointerReleased, swipeDirection, swipeThreshold, swiped,
        tapCount, tapped, verticalAlignment,
    ]
}

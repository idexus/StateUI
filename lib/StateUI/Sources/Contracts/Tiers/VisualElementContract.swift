// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every drawn element has: its size and its bounds, how it is shown and
/// turned, whether it answers input and holds the keyboard focus, the visual
/// states it enters, and what a screen reader says about it.
public enum VisualElementContract: Contract {
    /// The tier's name.
    public static let name = "VisualElement"

    /// Every drawn element carries values in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// How deep a heading the element is, for a user moving by headings.
    public static let accessibilityHeadingLevel = ElementProperty<Self, HeadingLevel>(
        "accessibilityHeadingLevel", layer: .native)

    /// What happens when the element is used, said after its label.
    public static let accessibilityHint = ElementProperty<Self, String>(
        "accessibilityHint", layer: .native)

    /// What a screen reader says the element is.
    public static let accessibilityLabel = ElementProperty<Self, String>(
        "accessibilityLabel", layer: .native)

    /// Whether the element and everything in it are left out of what a screen
    /// reader reads.
    public static let automationExcludedWithChildren = ElementProperty<Self, Bool>(
        "automationExcludedWithChildren", layer: .native)

    /// What is drawn behind the element: a colour, or a brush.
    public static let background = ElementProperty<Self, Background>(
        "background", layer: .native)

    /// Gives the element the keyboard focus, answering whether it took it.
    public static let focus = ElementAct<Self, Void, Bool>("focus")

    /// The frame the element settled on, fed by the host into a state.
    public static let frame = ElementProperty<Self, Rect>("frame", layer: .structure)

    /// The height the element asks for.
    public static let height = ElementProperty<Self, Double>(
        "height", layer: .native, moves: .height)

    /// Whether input passes through the element to what is under it.
    public static let ignoresInput = ElementProperty<Self, Bool>("ignoresInput", layer: .native)

    /// Whether a screen reader skips the element.
    public static let isAccessibilityHidden = ElementProperty<Self, Bool>(
        "isAccessibilityHidden", layer: .native)

    /// Whether the element answers input.
    public static let isEnabled = ElementProperty<Self, Bool>("isEnabled", layer: .native)

    /// The platform moved the focus onto the element, or off it.
    public static let isFocusedChanged = ElementEvent<Self, Bool>(
        "isFocusedChanged", layer: .native)

    /// Whether the element is shown.
    public static let isVisible = ElementProperty<Self, Bool>("isVisible", layer: .native)

    /// Which way the element lays its content out.
    public static let layoutDirection = ElementProperty<Self, LayoutDirection>(
        "layoutDirection", layer: .native)

    /// The most height the element takes.
    public static let maximumHeight = ElementProperty<Self, Double>(
        "maximumHeight", layer: .native, moves: .height)

    /// The most width the element takes.
    public static let maximumWidth = ElementProperty<Self, Double>(
        "maximumWidth", layer: .native, moves: .width)

    /// The least height the element takes.
    public static let minimumHeight = ElementProperty<Self, Double>(
        "minimumHeight", layer: .native, moves: .height)

    /// The least width the element takes.
    public static let minimumWidth = ElementProperty<Self, Double>(
        "minimumWidth", layer: .native, moves: .width)

    /// How opaque the element is, from 0 to 1.
    public static let opacity = ElementProperty<Self, Double>(
        "opacity", layer: .native, moves: .opacity)

    /// Where across the element it turns and scales about, as a fraction.
    public static let pivotX = ElementProperty<Self, Double>(
        "pivotX", layer: .native, moves: .transform)

    /// Where down the element it turns and scales about, as a fraction.
    public static let pivotY = ElementProperty<Self, Double>(
        "pivotY", layer: .native, moves: .transform)

    /// How far the element is turned in the screen's plane, in degrees.
    public static let rotation = ElementProperty<Self, Double>(
        "rotation", layer: .native, moves: .transform)

    /// How far the element is tipped about its horizontal axis, in degrees.
    public static let rotationX = ElementProperty<Self, Double>(
        "rotationX", layer: .native, moves: .transform)

    /// How far the element is turned about its vertical axis, in degrees.
    public static let rotationY = ElementProperty<Self, Double>(
        "rotationY", layer: .native, moves: .transform)

    /// How much the element is scaled, both ways.
    public static let scale = ElementProperty<Self, Double>(
        "scale", layer: .native, moves: .transform)

    /// How much the element is scaled across.
    public static let scaleX = ElementProperty<Self, Double>(
        "scaleX", layer: .native, moves: .transform)

    /// How much the element is scaled down.
    public static let scaleY = ElementProperty<Self, Double>(
        "scaleY", layer: .native, moves: .transform)

    /// The keyed style the element wears, by its key.
    public static let style = ElementProperty<Self, Name>("style", layer: .structure)

    /// How far the element is moved across from where its layout put it.
    public static let translationX = ElementProperty<Self, Double>(
        "translationX", layer: .native, moves: .place)

    /// How far the element is moved down from where its layout put it.
    public static let translationY = ElementProperty<Self, Double>(
        "translationY", layer: .native, moves: .place)

    /// Takes the keyboard focus off the element.
    public static let unfocus = ElementAct<Self, Void, Void>("unfocus")

    /// The element entered one of its visual states, the one it names.
    public static let visualStateChanged = ElementEvent<Self, String>(
        "visualStateChanged", layer: .stateUI)

    /// The width the element asks for.
    public static let width = ElementProperty<Self, Double>(
        "width", layer: .native, moves: .width)

    /// Which of its siblings the element is drawn over and under.
    public static let zIndex = ElementProperty<Self, Int>("zIndex", layer: .native, travels: false)

    /// The tier's own members.
    public static let members: [any ContractMember] = [
        accessibilityHeadingLevel, accessibilityHint, accessibilityLabel,
        automationExcludedWithChildren, background, focus, frame, height, ignoresInput,
        isAccessibilityHidden, isEnabled, isFocusedChanged, isVisible, layoutDirection,
        maximumHeight, maximumWidth, minimumHeight, minimumWidth, opacity, pivotX, pivotY,
        rotation, rotationX, rotationY, scale, scaleX, scaleY, style, translationX,
        translationY, unfocus, visualStateChanged, width, zIndex,
    ]
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A window onto a page.
public enum WindowContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Window"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The window came to the front.
    public static let activated = ElementEvent<Self, Void>("activated", layer: .adaptive)

    /// The platform made the window.
    public static let created = ElementEvent<Self, Void>("created", layer: .adaptive)

    /// The window is showing behind another.
    public static let deactivated = ElementEvent<Self, Void>("deactivated", layer: .adaptive)

    /// The window is going.
    public static let destroying = ElementEvent<Self, Void>("destroying", layer: .adaptive)

    /// Whether the window floats above the application's other windows.
    public static let floatsOnTop = ElementProperty<Self, Bool>(
        "floatsOnTop", layer: .adaptive, cleared: false)

    /// How tall the window is, in device units.
    public static let height = ElementProperty<Self, Double>("height", layer: .native, moves: .height)

    /// Whether the window hides while another scene of the application is in
    /// front.
    public static let hidesWhenInactive = ElementProperty<Self, Bool>(
        "hidesWhenInactive", layer: .adaptive, cleared: false)

    /// Whether the user can make the window fill the screen.
    public static let isMaximizable = ElementProperty<Self, Bool>("isMaximizable", layer: .adaptive)

    /// Whether the user can put the window away.
    public static let isMinimizable = ElementProperty<Self, Bool>("isMinimizable", layer: .adaptive)

    /// Whether the window's material shows through it.
    public static let isTranslucent = ElementProperty<Self, Bool>("isTranslucent", layer: .adaptive)

    /// The most height the window takes, in device units.
    public static let maximumHeight = ElementProperty<Self, Double>(
        "maximumHeight", layer: .native, moves: .height)

    /// The most width the window takes, in device units.
    public static let maximumWidth = ElementProperty<Self, Double>(
        "maximumWidth", layer: .native, moves: .width)

    /// The least height the window takes, in device units.
    public static let minimumHeight = ElementProperty<Self, Double>(
        "minimumHeight", layer: .native, moves: .height)

    /// The least width the window takes, in device units.
    public static let minimumWidth = ElementProperty<Self, Double>(
        "minimumWidth", layer: .native, moves: .width)

    /// A modal went without being told to, leaving this many presented.
    public static let modalPopped = ElementEvent<Self, Int>("modalPopped", layer: .adaptive)

    /// The window came back from out of sight.
    public static let resumed = ElementEvent<Self, Void>("resumed", layer: .adaptive)

    /// The window went out of sight.
    public static let stopped = ElementEvent<Self, Void>("stopped", layer: .adaptive)

    /// The window's title.
    public static let title = ElementProperty<Self, String>("title", layer: .native)

    /// How wide the window is, in device units.
    public static let width = ElementProperty<Self, Double>("width", layer: .native, moves: .width)

    /// What kind of window it is - the kind a scene declares it under.
    public static let windowType = ElementProperty<Self, WindowType>(
        "windowType", layer: .structure, cleared: false)

    /// The value a window of the kind was opened for, written down with it.
    public static let windowValue = ElementProperty<Self, String>(
        "windowValue", layer: .structure, cleared: false)

    /// Where the window stands across the screen, in device units.
    public static let x = ElementProperty<Self, Double>("x", layer: .structure)

    /// Where the window stands down the screen, in device units.
    public static let y = ElementProperty<Self, Double>("y", layer: .structure)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        activated, created, deactivated, destroying, floatsOnTop, height, hidesWhenInactive, isMaximizable,
        isMinimizable, isTranslucent, maximumHeight, maximumWidth, minimumHeight, minimumWidth, modalPopped,
        resumed, stopped, title, width, windowType, windowValue, x, y,
    ]
}

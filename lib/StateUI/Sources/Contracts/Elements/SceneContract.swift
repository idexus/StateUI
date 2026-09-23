// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One session of the application: its main window, the windows it opens beside
/// it, and the state they share.
public enum SceneContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Scene"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The scene came to the front.
    public static let activated = ElementEvent<Self, Void>("activated", layer: .adaptive)

    /// The scene is showing behind another.
    public static let deactivated = ElementEvent<Self, Void>("deactivated", layer: .adaptive)

    /// The scene is ending.
    public static let destroying = ElementEvent<Self, Void>("destroying", layer: .adaptive)

    /// The scene went out of sight.
    public static let stopped = ElementEvent<Self, Void>("stopped", layer: .adaptive)

    /// The user closed one of the scene's windows, which the key names.
    public static let windowClosed = ElementEvent<Self, String>("windowClosed", layer: .adaptive)

    /// The platform restored a window the scene had open: its kind, and the
    /// value it was opened for.
    public static let windowRestored = ElementEvent<Self, (String, String?)>(
        "windowRestored", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        activated, deactivated, destroying, stopped, windowClosed, windowRestored,
    ]
}

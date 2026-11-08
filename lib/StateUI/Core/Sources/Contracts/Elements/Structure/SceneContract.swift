// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One of the application's scenes, standing while a window of it is open: its
/// windows, and the state they share.
public enum SceneContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Scene"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The user closed one of the scene's windows, which the key names.
    public static let windowClosed = ElementEvent<Self, String>("windowClosed", layer: .adaptive)

    /// The tiers it wears.
    public static let tiers: [any Tier.Type] = [SessionElementContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = [windowClosed]
}

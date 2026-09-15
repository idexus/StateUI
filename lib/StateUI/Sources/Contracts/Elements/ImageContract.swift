// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A picture from the application's resources.
public enum ImageContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .image

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// An image is a view whose picture is fitted.
    public static let tiers: [any Contract.Type] = [ViewContract.self, ImageElementContract.self]

    /// Whether an animated picture is running.
    public static let isAnimating = ElementProperty<Self, Bool>("isAnimating", layer: .native)

    /// The picture shown.
    public static let source = ElementProperty<Self, ImageSource>("source", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [isAnimating, source]
}

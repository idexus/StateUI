// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Every contract the library declares, the tiers first - what the guards
/// holding the contracts read, and what the tables derived from them are
/// built out of.
enum LibraryContracts {
    /// The tiers, in the dictionary's order.
    static let tiers: [any Contract.Type] = [
        PropertyContainerContract.self,
        VisualElementContract.self,
        ViewContract.self,
        LayoutContract.self,
        StackBaseContract.self,
        InputViewContract.self,
        ShapeContract.self,
        TextElementContract.self,
        TextStyleElementContract.self,
        FontElementContract.self,
        TextAlignmentElementContract.self,
        LineHeightElementContract.self,
        DecorableTextElementContract.self,
        PaddingElementContract.self,
        BorderElementContract.self,
        ImageElementContract.self,
        TintElementContract.self,
        BarElementContract.self,
        MenuItemElementContract.self,
        PageElementContract.self,
    ]

    /// Every contract.
    static let all: [any Contract.Type] = tiers
}

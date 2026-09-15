// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a container shows as a screen: a window's page, a stack's root and
/// destinations, a tab, either half of a split view, a sheet.
public enum PageContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .page

    /// Every base host presents it by its platform's conventions, keeping
    /// StateUI's state contract.
    public static let layer: ElementLayer = .adaptive

    /// A page shows a title and an icon where it is an item.
    public static let tiers: [any Contract.Type] = [PageElementContract.self]

    /// The page is coming on screen.
    public static let appearing = ElementEvent<Self, Void>("appearing", layer: .adaptive)

    /// What the back affordance says on the page pushed above this one.
    public static let backButtonTitle = ElementProperty<Self, String>("backButtonTitle", layer: .adaptive)

    /// What is drawn behind the page.
    public static let background = ElementProperty<Self, Color>("background", layer: .native)

    /// The page is leaving the screen.
    public static let disappearing = ElementEvent<Self, Void>("disappearing", layer: .adaptive)

    /// Whether the page offers a way back.
    public static let hasBackButton = ElementProperty<Self, Bool>("hasBackButton", layer: .adaptive)

    /// Whether the bar shows above the page.
    public static let hasNavigationBar = ElementProperty<Self, Bool>("hasNavigationBar", layer: .adaptive)

    /// The reader has left the page for another.
    public static let navigatedFrom = ElementEvent<Self, Void>("navigatedFrom", layer: .adaptive)

    /// The reader has arrived at the page.
    public static let navigatedTo = ElementEvent<Self, Void>("navigatedTo", layer: .adaptive)

    /// The reader is leaving the page for another.
    public static let navigatingFrom = ElementEvent<Self, Void>("navigatingFrom", layer: .adaptive)

    /// The room kept inside the page's edges, in device units.
    public static let padding = ElementProperty<Self, Insets>("padding", layer: .native, moves: .spacing)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        appearing, backButtonTitle, background, disappearing, hasBackButton, hasNavigationBar, navigatedFrom,
        navigatedTo, navigatingFrom, padding,
    ]
}

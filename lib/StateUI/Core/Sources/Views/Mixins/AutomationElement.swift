// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An element the platform's automation meets - a drawn element, a menu's entry or a bar's item, an arrangement of
/// pages - and finds by its name. A `Style` names none: a name is one element's.
public protocol AutomationElement: PropertyContainer {}

extension AutomationElement {
    /// A stable name that automation finds this by.
    ///
    ///     Button("Save").accessibilityIdentifier("save")
    ///     ToolbarButton("Home").accessibilityIdentifier("chrome.home")
    ///
    /// Nothing shows it and no screen reader says it: it is the handle a UI
    /// test, a script or an agent asks the platform's automation for. What a
    /// screen-reader user hears is `.accessibilityLabel`. Keep it stable
    /// across renders and unique on the page.
    public func accessibilityIdentifier(_ value: String) -> Modified {
        setValue(AutomationElementContract.accessibilityIdentifier, value)
    }
}

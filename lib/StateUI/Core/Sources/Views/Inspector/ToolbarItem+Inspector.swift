// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension ToolbarItem {
    /// The button that shows its scene's inspector docked in its window, and
    /// hides it again - for a page's `.toolbar { }`. See `Inspector`.
    ///
    ///     @Environment(\.window) private var window
    ///
    ///     VStack { … }
    ///         .toolbar { ToolbarItem.inspector(window) }
    ///
    /// - Parameter window: the window it stands in - the page's own.
    public static func inspector(_ window: WindowSession) -> ToolbarItem {
        ToolbarItem("ⓘ")
            .id("stateui.inspector")
            .accessibilityIdentifier("stateui.inspector")
            .onClicked { Inspector.toggle(in: window) }
    }
}

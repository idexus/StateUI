// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension ToolbarButton {
    /// The button that shows its scene's inspector docked in its window, and
    /// hides it again - for a page's `.toolbar { }`. See `DebugInspector`.
    ///
    ///     @Environment(\.window) private var window
    ///
    ///     VStack { … }
    ///         .toolbar { ToolbarButton.debugInspector(window) }
    ///
    /// - Parameters:
    ///   - window: the window it stands in - the page's own.
    ///   - text: what it says, on a bar that shows words and to assistive technology; `ⓘ` until told otherwise.
    public static func debugInspector(_ window: WindowSession, text: String = "ⓘ") -> ToolbarButton {
        ToolbarButton(text)
            .id("stateui.inspector")
            .accessibilityIdentifier("stateui.inspector")
            .onClicked { window.toggleDebugInspector() }
    }
}

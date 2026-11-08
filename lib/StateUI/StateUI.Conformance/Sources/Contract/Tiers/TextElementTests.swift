// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TextElementContract` on a host: an element shows the words the tree gives it, and the words the tree changes them
/// to - a control's caption, a text's or a field's words, a menu's caption and its items', a bar's label.
@_spi(Host) public enum TextElementTests: ConformanceFamily {
    public static let name = "TextElement"

    public static var cases: [ConformanceCase] {
        (TextualElementTests.written + MenuTests.written + ToolbarLabelTests.written + MenuItemElementCases.written)
            .proving(TextElementContract.self)
    }
}

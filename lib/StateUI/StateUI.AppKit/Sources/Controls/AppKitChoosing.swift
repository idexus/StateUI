// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A picker as AppKit shows it - a pop-up button, a segmented control or a column of radio buttons - written and
/// heard alike: the user's choice is told, the program's never.
/// Design: docs/design/views/controls.md#a-pickers-presentation
@MainActor
protocol AppKitChoosing: NSView {
    /// What the picker does as the user chooses, handed the place, and opens or closes its list, where it has one.
    var onSelectionChanged: ((Int) -> Void)? { get set }
    var onOpened: (() -> Void)? { get set }
    var onClosed: (() -> Void)? { get set }

    /// The captions offered and the place of the choice, -1 for none, as AppKit holds them.
    var itemTitles: [String] { get }
    var indexOfSelectedItem: Int { get }
    var isEnabled: Bool { get set }

    /// Writes the choices, the choice where the tree changed it, the look and whether the list shows.
    func apply(
        items: [String], selectedIndex: Int, writeSelection: Bool, title: String?, font: NSFont, textColor: NSColor,
        tint: NSColor?, alignment: NSTextAlignment, enabled: Bool, open: Bool, writeOpen: Bool)

    /// Chooses the item at `index` as the user does.
    func chooseForTesting(index: Int)
}

extension AppKitPickerView: AppKitChoosing {}
#endif

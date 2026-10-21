// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import CStateUIWinUI

/// The Edit menu's own entries, done by the text box the user last typed into.
/// Design: docs/design/platforms/winui/pages.md#the-edit-menu
@MainActor
enum WinUIEditing {
    /// The field the user last typed into; nil where none stands.
    static weak var typed: WinUIView?

    /// Does `command` to that field.
    static func perform(_ command: EditCommand) {
        guard let typed else { return }
        stateui_winui_field_edit(typed.handle, Int32(EditCommand.allCases.firstIndex(of: command) ?? 0))
    }
}

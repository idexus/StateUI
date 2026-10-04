// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A TextField: a WinUI `TextBox` on one line, whose Enter submits - a `PasswordBox` while it holds a password.
/// Design: docs/design/platforms/winui/controls.md#a-password
@MainActor
final class WinUITextFieldView: WinUITextInputView {
    /// Whether the field stands as a `PasswordBox`.
    private(set) var isPassword = false

    init() {
        super.init { number in stateui_winui_field_make(number) }
    }

    /// Stands a `PasswordBox`, or a `TextBox` again, in the field's place, holding its words.
    func setPassword(_ password: Bool) {
        guard password != isPassword else { return }

        let words = text
        isPassword = password
        replaceNative(with: password ? stateui_winui_password_make(number) : stateui_winui_field_make(number))
        ProgramWrite.perform { setText(words) }
    }
}

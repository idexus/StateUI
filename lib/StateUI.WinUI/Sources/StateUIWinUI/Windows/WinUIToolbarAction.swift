// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One action a window's chrome performs for the arrangement it shows.
@MainActor
struct WinUIToolbarAction {
    let title: String
    let isEnabled: Bool
    let perform: () -> Void

    /// Whether two actions draw the same button. What an action performs is taken again on every composition.
    func draws(like other: WinUIToolbarAction) -> Bool {
        title == other.title && isEnabled == other.isEnabled
    }
}

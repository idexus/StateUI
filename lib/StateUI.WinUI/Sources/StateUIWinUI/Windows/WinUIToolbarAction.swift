// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One action a window's chrome performs for the arrangement it shows.
@MainActor
struct WinUIToolbarAction {
    let title: String
    let isEnabled: Bool
    var identifier: String?
    /// The files its picture may stand in, in order (`PictureArithmetic.files`); none for words alone.
    var icon: [String] = []
    /// Whether performing it destroys something.
    var isDestructive = false
    /// Whether its words stand beside its picture (`MountedElement.showsActionWords`).
    var showsWords = true
    let perform: () -> Void

    /// Whether two actions draw the same button. What an action performs is taken again on every composition.
    func draws(like other: WinUIToolbarAction) -> Bool {
        title == other.title && isEnabled == other.isEnabled && identifier == other.identifier && icon == other.icon
            && isDestructive == other.isDestructive && showsWords == other.showsWords
    }
}

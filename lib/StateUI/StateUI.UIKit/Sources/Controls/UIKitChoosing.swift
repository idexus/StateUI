// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A picker as UIKit shows it - a pop-up button, a segmented control or a column of radio buttons - written and
/// heard alike: the user's choice is told, the program's is only shown.
/// Design: docs/design/views/controls.md#a-pickers-presentation
@MainActor
protocol UIKitChoosing: UIView {
    /// What the picker does as the user chooses, handed the place, and opens or closes its list, where it has one.
    var onChosen: ((Int) -> Void)? { get set }
    var onOpened: (() -> Void)? { get set }
    var onClosed: (() -> Void)? { get set }

    /// The choices offered, the one shown - nil for none - and what the picker says while none is.
    var choices: [String] { get }
    var chosen: Int? { get }
    var title: String? { get }
    var isEnabled: Bool { get set }

    /// The choices, the tree's choice - written only where the tree changed it or the choices - and the title.
    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool, title: String?)

    /// The user chose the choice at `place`.
    func userChose(_ place: Int)

    /// The words' look - the control's own where it says nothing - and where they stand across it.
    func setLook(_ look: TextLook, alignment: TextAlignment)

    /// The color the control marks with; nil for its own.
    func setTint(_ tint: UIColor?)
}

extension UIKitPickerView: UIKitChoosing {}
#endif

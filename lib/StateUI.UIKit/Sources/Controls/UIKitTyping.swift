// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What every view the user types in does with the words: the user's reported, cut to the view's bound
/// (`InputWords`); none taken while it is read only; the return key heard as submitting a field. The delegate of a
/// field and of an editor alike.
/// Design: docs/design/platforms/uikit/controls.md#a-field-and-its-words
@MainActor
final class UIKitTyping: NSObject, UITextFieldDelegate, UITextViewDelegate {
    /// What the view does when the user changed its words, handed all of them.
    var onTextChanged: ((String) -> Void)?

    /// What a field does when the user submits it with the return key.
    var onSubmitted: (() -> Void)?

    /// How many characters the view accepts; nil for no bound.
    var maximumLength: Int?

    /// Whether the user can change the words.
    var isReadOnly = false

    /// Reports the words the user left: the view's own, or the first of them its bound keeps - which the view shows
    /// instead, handed back.
    func heard(_ typed: String) -> String? {
        let cut = InputWords.cut(typed, toBound: maximumLength)
        onTextChanged?(cut ?? typed)
        return cut
    }

    func textField(
        _ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String
    ) -> Bool {
        !isReadOnly
    }

    func textFieldShouldReturn(_ field: UITextField) -> Bool {
        onSubmitted?()
        return true
    }

    func textViewDidChange(_ view: UITextView) {
        if let cut = heard(view.text) { view.text = cut }
    }
}
#endif

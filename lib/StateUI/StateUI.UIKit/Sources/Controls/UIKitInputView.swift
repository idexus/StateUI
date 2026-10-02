// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view the user types words in - a field on one line or an editor of several - taking what the tree says of
/// them only where the tree changed it, which keeps the user's typing and caret their own.
/// Design: docs/design/platforms/uikit/controls.md#a-field-and-its-words
@MainActor
protocol UIKitInputView: UIView, UITextInput {
    /// What the view does with the words the user types.
    var typing: UIKitTyping { get }

    /// The words the view shows now.
    var words: String { get }

    /// Writes the words where they differ from the view's.
    func setText(_ words: String)

    /// The words shown while there are none, in `color` where one is given.
    func setPlaceholder(_ placeholder: String?, color: UIColor?)

    /// Whether the view takes input at all, whether the user can change the words, and what the keyboard is told of
    /// them.
    func setBehaviour(enabled: Bool, readOnly: Bool, keyboard: UIKitKeyboard)

    /// The words' look: the view's own where it says nothing.
    func setLook(_ look: TextLook)

    /// The words across the view.
    func setAlignment(_ alignment: TextAlignment)
}

extension UIKitInputView {
    /// Puts the caret `start` characters in and selects `length` from it.
    func select(start: Int, length: Int) {
        let units = InputWords.utf16Selection(start: start, length: length, in: words)
        guard let from = position(from: beginningOfDocument, offset: units.start),
              let to = position(from: from, offset: units.length)
        else { return }
        selectedTextRange = textRange(from: from, to: to)
    }

    /// How many characters stand before the caret, and how many it selects.
    var selection: (start: Int, length: Int) {
        guard let range = selectedTextRange else { return (0, 0) }
        let units = Array(words.utf16)
        let start = offset(from: beginningOfDocument, to: range.start)
        let end = offset(from: beginningOfDocument, to: range.end)
        func characters(_ count: Int) -> Int {
            String(decoding: units.prefix(max(0, count)), as: UTF16.self).count
        }
        return (characters(start), characters(end) - characters(start))
    }

    /// A line's start and end as the view's own direction says them.
    func alignment(_ alignment: TextAlignment) -> NSTextAlignment {
        switch alignment {
        case .start: .natural
        case .center: .center
        case .end: effectiveUserInterfaceLayoutDirection == .rightToLeft ? .left : .right
        }
    }
}

extension UIKitInputView where Self: UITextField {
    var words: String { text ?? "" }

    func setText(_ words: String) {
        if text != words { text = words }
    }

    func setPlaceholder(_ placeholder: String?, color: UIColor?) {
        guard let placeholder else { return attributedPlaceholder = nil }
        attributedPlaceholder = NSAttributedString(
            string: placeholder, attributes: color.map { [.foregroundColor: $0] } ?? [:])
    }

    func setBehaviour(enabled: Bool, readOnly: Bool, keyboard: UIKitKeyboard) {
        isEnabled = enabled
        typing.isReadOnly = readOnly
        keyboard.apply(to: self)
    }

    func setAlignment(_ alignment: TextAlignment) {
        textAlignment = self.alignment(alignment)
    }

    /// What the keyboard's return key says; a keyboard already up takes it at once.
    func setReturnKey(_ key: ReturnKey) {
        returnKeyType = switch key {
        case .default: .default
        case .go: .go
        case .search: .search
        case .send: .send
        case .next: .next
        case .done: .done
        }
        if isFirstResponder { reloadInputViews() }
    }

    /// Hears the user's words as they change.
    func hearTyping() {
        delegate = typing
        addAction(UIAction { [weak self] _ in
            guard let self, let cut = typing.heard(words) else { return }
            text = cut
        }, for: .editingChanged)
    }
}
#endif

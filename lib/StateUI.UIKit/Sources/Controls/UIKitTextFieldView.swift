// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TextField: UIKit's own field. The user's words are reported, cut to the field's bound (`InputWords`); the
/// program's are only written.
@MainActor
final class UIKitTextFieldView: UITextField, UITextFieldDelegate {
    /// What the field does when the user changed its words.
    var onTextChanged: ((String) -> Void)?

    /// What the field does when the user submits it with the return key.
    var onSubmitted: (() -> Void)?

    /// How many characters the field accepts; nil for no bound.
    var maximumLength: Int?

    private let madeFont = UIFont.preferredFont(forTextStyle: .body)

    init() {
        super.init(frame: .zero)
        borderStyle = .roundedRect
        font = madeFont
        delegate = self
        addAction(UIAction { [weak self] _ in self?.changed() }, for: .editingChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitTextFieldView is made in code")
    }

    /// The program's words: written, and heard by nobody.
    func setText(_ words: String) {
        if text != words { text = words }
    }

    /// The words' look: the field's own where it says nothing.
    func setLook(_ look: TextLook) {
        font = .stateUI(look, standing: madeFont)
        textColor = look.color.flatMap(UIColor.init(stateUI:)) ?? .label
    }

    private func changed() {
        let typed = text ?? ""
        if let cut = InputWords.cut(typed, toBound: maximumLength) {
            text = cut
            onTextChanged?(cut)
        } else {
            onTextChanged?(typed)
        }
    }

    func textFieldShouldReturn(_ field: UITextField) -> Bool {
        onSubmitted?()
        return true
    }
}
#endif

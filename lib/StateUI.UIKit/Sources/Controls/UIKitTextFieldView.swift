// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TextField: UIKit's own field on one line. The user's words are reported; the program's are only written.
@MainActor
final class UIKitTextFieldView: UITextField, UIKitInputView {
    let typing = UIKitTyping()

    private let madeFont = UIFont.preferredFont(forTextStyle: .body)

    init() {
        super.init(frame: .zero)
        borderStyle = .roundedRect
        font = madeFont
        hearTyping()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitTextFieldView is made in code")
    }

    func setLook(_ look: TextLook) {
        font = .stateUI(look, standing: madeFont)
        textColor = look.color.flatMap(UIColor.init(stateUI:)) ?? .label
    }
}
#endif

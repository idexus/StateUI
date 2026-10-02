// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A SearchField: UIKit's own search field, its return key a search. The user's words are reported; the program's
/// are only written.
@MainActor
final class UIKitSearchFieldView: UISearchTextField, UIKitInputView {
    let typing = UIKitTyping()

    private let madeFont = UIFont.preferredFont(forTextStyle: .body)

    init() {
        super.init(frame: .zero)
        font = madeFont
        setReturnKey(InputTraits.submitLabel(nil, searching: true))
        hearTyping()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitSearchFieldView is made in code")
    }

    func setLook(_ look: TextLook) {
        font = .stateUI(look, standing: madeFont)
        textColor = look.color.flatMap(UIColor.init(stateUI:)) ?? .label
    }
}
#endif

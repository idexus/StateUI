// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Button: UIKit's own, its words its title; a tap is its click.
@MainActor
final class UIKitButtonView: UIButton {
    /// What the button does when the user taps it.
    var onClicked: (() -> Void)?

    private var look = TextLook()

    init() {
        super.init(frame: .zero)
        configuration = .plain()
        addAction(UIAction { [weak self] _ in self?.onClicked?() }, for: .primaryActionTriggered)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitButtonView is made in code")
    }

    /// The button's words.
    func setText(_ text: String) {
        configuration?.title = text
        applyLook()
    }

    /// The words' look: the button's own where it says nothing.
    func setLook(_ look: TextLook) {
        self.look = look
        applyLook()
    }

    private func applyLook() {
        let font = UIFont.stateUI(look, standing: .preferredFont(forTextStyle: .body))
        let color = look.color.flatMap(UIColor.init(stateUI:))
        configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font
            if let color { attributes.foregroundColor = color }
            return attributes
        }
    }
}
#endif

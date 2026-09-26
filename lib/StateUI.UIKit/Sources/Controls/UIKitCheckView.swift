// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A CheckBox or a RadioButton: UIKit has neither, so a button of its own showing the system's symbol for a box or a
/// circle, ticked or not, before a radio button's caption. A tap turns a box either way and a radio button only on;
/// the host layer takes the tick from its group.
@MainActor
final class UIKitCheckView: UIButton {
    /// What the view does when the user turned it.
    var onToggled: ((Bool) -> Void)?

    private let radio: Bool

    /// Whether it is ticked, as the tree last said or the user turned it.
    private(set) var isOn = false

    init(radio: Bool) {
        self.radio = radio
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.plain()
        configuration.imagePadding = 8
        configuration.contentInsets = .zero
        self.configuration = configuration
        contentHorizontalAlignment = .leading
        showTick()
        addAction(UIAction { [weak self] _ in self?.tapped() }, for: .primaryActionTriggered)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitCheckView is made in code")
    }

    /// Ticks it or not, as the program says: shown, and heard by nobody.
    func setOn(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        showTick()
    }

    /// A radio button's caption.
    func setText(_ text: String) {
        configuration?.title = text.isEmpty ? nil : text
    }

    /// The caption's look: the button's own where it says nothing.
    func setLook(_ look: TextLook) {
        let font = UIFont.stateUI(look, standing: .preferredFont(forTextStyle: .body))
        let color = look.color.flatMap(UIColor.init(stateUI:)) ?? .label
        configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font
            attributes.foregroundColor = color
            return attributes
        }
    }

    private func tapped() {
        guard !radio || !isOn else { return }
        isOn.toggle()
        showTick()
        onToggled?(isOn)
    }

    private func showTick() {
        let symbol = radio ? (isOn ? "largecircle.fill.circle" : "circle") : (isOn ? "checkmark.square.fill" : "square")
        configuration?.image = UIImage(systemName: symbol)
        accessibilityTraits = isOn ? [.button, .selected] : .button
    }
}
#endif

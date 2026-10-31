// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A CheckBox: UIKit has none, so a button of its own showing the system's symbol for a box, ticked or not, before
/// the words it says. A tap on the box or its words turns it either way, and VoiceOver names it by its words.
@MainActor
final class UIKitCheckView: UIButton {
    /// What the view does when the user turned it.
    var onToggled: ((Bool) -> Void)?

    /// Whether it is ticked, as the tree last said or the user turned it.
    private(set) var isOn = false

    init() {
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.plain()
        configuration.imagePadding = 8
        configuration.contentInsets = .zero
        self.configuration = configuration
        followTextSize()
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

    /// The words it says beside its box.
    func setText(_ text: String) {
        configuration?.title = text.isEmpty ? nil : text
    }

    /// The words' look: the button's own where the tree says nothing.
    func setLook(_ look: TextLook) {
        let color = look.color.flatMap(UIColor.init(stateUI:)) ?? .label
        configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.stateUI(look)
            attributes.foregroundColor = color
            return attributes
        }
    }

    private func tapped() {
        isOn.toggle()
        showTick()
        onToggled?(isOn)
    }

    private func showTick() {
        let symbol = isOn ? "checkmark.square.fill" : "square"
        configuration?.image = UIImage(systemName: symbol)
        accessibilityTraits = isOn ? [.button, .selected] : .button
    }
}
#endif

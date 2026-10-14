// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A picker offering its values as radio buttons. UIKit has none: a column of its buttons, each marked by a filled
/// circle while chosen and an empty one while not, the one chosen read as selected.
/// Design: docs/design/views/controls.md#a-pickers-presentation
@MainActor
final class UIKitRadioPickerView: UIStackView, UIKitChoosing {
    var onChosen: ((Int) -> Void)?
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?

    /// The choices and the choice as the tree last wrote them (`PickerChoices`).
    private var written = PickerChoices()

    private(set) var chosen: Int?
    private(set) var title: String?
    private var look = TextLook()
    private var tint: UIColor?

    var choices: [String] { written.choices }

    var isEnabled = true {
        didSet { for button in buttons { button.isEnabled = isEnabled } }
    }

    private var buttons: [UIButton] { arrangedSubviews.compactMap { $0 as? UIButton } }

    init() {
        super.init(frame: .zero)
        axis = .vertical
        alignment = .leading
        spacing = 4
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("UIKitRadioPickerView is made in code")
    }

    /// The column's own size: its buttons' one under another, the widest across - what StateUI's layout measures it
    /// by, where Auto Layout would.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let sizes = buttons.map { $0.sizeThatFits(size) }
        return CGSize(
            width: sizes.map(\.width).max() ?? 0,
            height: sizes.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, sizes.count - 1)))
    }

    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool, title: String?) {
        let write = written.write(choices, chosen: chosen, choiceChanged: writeChosen)
        if let shown = write.choices {
            for button in buttons { button.removeFromSuperview() }
            for place in shown.indices {
                let button = UIButton(configuration: .plain(), primaryAction: UIAction { [weak self] _ in
                    self?.userChose(place)
                })
                button.isEnabled = isEnabled
                addArrangedSubview(button)
            }
            invalidateIntrinsicContentSize()
        }
        if write.writesChoice { self.chosen = write.chosen }
        self.title = title
        mark()
    }

    func userChose(_ place: Int) {
        guard written.choices.indices.contains(place) else { return }
        chosen = place
        mark()
        onChosen?(place)
    }

    func setLook(_ look: TextLook, alignment: TextAlignment) {
        self.look = look
        self.alignment = switch alignment {
        case .start: .leading
        case .center: .center
        case .end: .trailing
        }
        mark()
    }

    func setTint(_ tint: UIColor?) {
        self.tint = tint
        mark()
    }

    /// Dresses each button: its caption in the picker's look, a filled circle for the one chosen and an empty one
    /// for the rest.
    private func mark() {
        for (place, button) in buttons.enumerated() {
            var configuration = button.configuration ?? .plain()
            let on = place == chosen
            configuration.title = written.choices[place]
            configuration.image = UIImage(systemName: on ? "largecircle.fill.circle" : "circle")
            configuration.imagePadding = 8
            configuration.imageColorTransformer = tint.map { tint in UIConfigurationColorTransformer { _ in tint } }
            configuration.titleTextAttributesTransformer = look.titleTransformer(color: .label)
            button.configuration = configuration
            button.accessibilityTraits = on ? [.button, .selected] : .button
        }
    }
}
#endif

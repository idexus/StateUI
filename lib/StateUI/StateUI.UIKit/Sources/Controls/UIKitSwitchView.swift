// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Switch: UIKit's own, and the words it says beside it - the words at its start, the switch at its end, as iOS
/// stands a switch in its settings. A tap on the words flips it, and the switch carries them as its name. The user's
/// turn is reported; the program's is only shown.
/// Design: docs/design/platforms/uikit/controls.md#a-switchs-words
@MainActor
final class UIKitSwitchView: UIView, UIKitAccessibilityPresenting {
    /// What the switch does when the user turned it.
    var onToggled: ((Bool) -> Void)?

    /// The switch itself, which the user and VoiceOver act on.
    let control = UISwitch()

    /// The words beside it; hidden where it says none.
    let caption = UILabel()

    /// The room between the words and the switch.
    private static let gap: CGFloat = 8

    // A switch is the size it makes itself, whatever frame it is given: measured as it measures itself, not by its
    // intrinsic size, which can differ.

    var presentedControl: UIView { control }

    /// The name the author gives the switch for VoiceOver; nil leaves it named by its words.
    var authoredLabel: String? {
        didSet { name() }
    }

    init() {
        super.init(frame: .zero)
        control.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onToggled?(control.isOn)
        }, for: .valueChanged)
        caption.isHidden = true
        caption.isAccessibilityElement = false
        caption.font = .preferredFont(forTextStyle: .body)
        caption.adjustsFontForContentSizeCategory = true
        caption.isUserInteractionEnabled = true
        caption.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(captionTapped)))
        addSubview(caption)
        addSubview(control)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitSwitchView is made in code")
    }

    /// Whether the switch is on.
    var isOn: Bool { control.isOn }

    /// Turns it as the program says: shown, and heard by nobody.
    func setOn(_ on: Bool) {
        control.setOn(on, animated: false)
    }

    /// Whether the user may turn it; its words dim with it.
    func setEnabled(_ enabled: Bool) {
        control.isEnabled = enabled
        caption.isEnabled = enabled
    }

    /// The words beside it, in the colour the tree gives them, else the platform's.
    func setCaption(_ text: String, color: UIColor?) {
        caption.text = text
        caption.textColor = color ?? .label
        caption.isHidden = text.isEmpty
        name()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize { sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 0)) }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let toggle = control.sizeThatFits(.zero)
        guard !caption.isHidden else { return toggle }
        let room = max(0, size.width - toggle.width - Self.gap)
        let words = caption.sizeThatFits(CGSize(width: room, height: .greatestFiniteMagnitude))
        return CGSize(width: words.width + Self.gap + toggle.width, height: max(words.height, toggle.height))
    }

    /// The switch at the end, the words in the rest from the start - the end and the start as the view lays out.
    override func layoutSubviews() {
        super.layoutSubviews()
        let toggle = control.sizeThatFits(.zero)
        let rightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let room = max(0, bounds.width - toggle.width - Self.gap)
        control.frame = CGRect(
            x: rightToLeft ? 0 : bounds.width - toggle.width, y: (bounds.height - toggle.height) / 2,
            width: toggle.width, height: toggle.height)
        caption.frame = CGRect(x: rightToLeft ? bounds.width - room : 0, y: 0, width: room, height: bounds.height)
    }

    /// The switch named for VoiceOver by the author's label, else by its words.
    private func name() {
        control.accessibilityLabel = authoredLabel ?? (caption.isHidden ? nil : caption.text)
    }

    @objc private func captionTapped() {
        guard control.isEnabled else { return }
        control.setOn(!control.isOn, animated: true)
        control.sendActions(for: .valueChanged)
    }

    func tapWordsForTesting() {
        captionTapped()
    }
}
#endif

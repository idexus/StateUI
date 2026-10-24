// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A link: AppKit has no control of its own for one, so a borderless button whose words stand underlined in the
/// system's link color - or the color the tree gives them - under the pointing hand, a link to VoiceOver.
/// Design: docs/design/platforms/appkit/views.md#a-link
@MainActor
final class AppKitLinkView: NSButton {
    /// What a click does: the host layer opens the link's address.
    var onClicked: (() -> Void)?

    init() {
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryChange)
        target = self
        action = #selector(clicked)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitLinkView is created in code")
    }

    /// Its words, in `color` - the system's link color where nil - underlined, and whether it can be chosen.
    func apply(text: String, color: NSColor?, enabled: Bool) {
        attributedTitle = NSAttributedString(string: text, attributes: [
            .foregroundColor: color ?? .linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
        ])
        setAccessibilityLabel(text)
        isEnabled = enabled
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func accessibilityRole() -> NSAccessibility.Role? { .link }

    @objc private func clicked() {
        onClicked?()
    }
}
#endif

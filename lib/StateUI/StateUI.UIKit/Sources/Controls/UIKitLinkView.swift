// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A link: UIKit has no control of its own for one, so a plain button whose words stand underlined in the system's
/// link color - or the color the tree gives them - a link to VoiceOver.
/// Design: docs/design/platforms/uikit/controls.md#a-link
@MainActor
final class UIKitLinkView: UIButton {
    /// What a tap does: the host layer opens the link's address.
    var onClicked: (() -> Void)?

    /// The words, and the color they stand in; nil for the system's link color.
    private var words = ""
    private var color: UIColor?

    init() {
        super.init(frame: .zero)
        var plain = UIButton.Configuration.plain()
        plain.contentInsets = .zero
        configuration = plain
        accessibilityTraits = .link
        addAction(UIAction { [weak self] _ in self?.onClicked?() }, for: .primaryActionTriggered)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitLinkView is made in code")
    }

    /// Its words, in `color` - the system's link color where nil - underlined.
    func show(_ text: String, color: UIColor?) {
        words = text
        self.color = color
        var title = AttributedString(text)
        title.foregroundColor = color ?? .link
        title.uiKit.underlineStyle = .single
        configuration?.attributedTitle = title
        accessibilityLabel = text
    }

    /// The words it shows.
    var wordsForTesting: String { words }
}
#endif

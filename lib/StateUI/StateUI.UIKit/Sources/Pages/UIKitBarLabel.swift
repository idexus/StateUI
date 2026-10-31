// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// A bar's words nobody chooses (`ToolbarLabel`): its picture before its words, in the footnote's size.
@MainActor
final class UIKitBarLabel: UIStackView {
    let words = UILabel()
    let picture = UIImageView()

    init(_ text: String, image: UIImage?) {
        super.init(frame: .zero)
        spacing = 6
        alignment = .center
        words.text = text
        words.font = .preferredFont(forTextStyle: .footnote)
        words.adjustsFontForContentSizeCategory = true
        picture.image = image
        picture.isHidden = image == nil
        addArrangedSubview(picture)
        addArrangedSubview(words)
        isAccessibilityElement = true
        accessibilityLabel = text
        accessibilityTraits = .staticText
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("UIKitBarLabel is made in code")
    }

    /// Its words and picture in `tint`, else in the secondary color of words.
    func tint(_ tint: UIColor?) {
        words.textColor = tint ?? .secondaryLabel
        picture.tintColor = tint ?? .secondaryLabel
    }
}
#endif

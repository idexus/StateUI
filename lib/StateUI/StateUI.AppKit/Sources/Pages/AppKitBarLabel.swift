// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A bar's words nobody chooses (`ToolbarLabel`): its picture before its words, small and in the secondary color of
/// words, as a window's status words stand.
@MainActor
final class AppKitBarLabel: NSStackView {
    let words = NSTextField(labelWithString: "")
    let picture = NSImageView()

    init(_ text: String, image: NSImage?) {
        super.init(frame: .zero)
        orientation = .horizontal
        spacing = 4
        words.stringValue = text
        words.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        words.textColor = .secondaryLabelColor
        picture.image = image
        picture.contentTintColor = .secondaryLabelColor
        picture.isHidden = image == nil
        addArrangedSubview(picture)
        addArrangedSubview(words)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

#endif

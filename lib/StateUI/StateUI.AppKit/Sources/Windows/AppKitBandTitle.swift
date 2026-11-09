// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// The page's title where a painted band hides the system's own: its words, and the line under them where the page
/// says one, in the band's words' color - as the system stands a title and a subtitle in a toolbar.
/// Design: docs/design/platforms/appkit/runtime.md#the-bars-band
@MainActor
final class AppKitBandTitle: NSStackView {
    let words = NSTextField(labelWithString: "")
    let line = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 0
        words.font = .systemFont(ofSize: 15, weight: .bold)
        words.lineBreakMode = .byTruncatingTail
        line.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        line.lineBreakMode = .byTruncatingTail
        addArrangedSubview(words)
        addArrangedSubview(line)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitBandTitle is created in code")
    }

    /// Shows `title` and, under it, `subtitle` - none where nil - in `color`, the line a little fainter, at the size
    /// they ask.
    func show(title: String, subtitle: String?, color: NSColor) {
        words.stringValue = title
        words.textColor = color
        line.stringValue = subtitle ?? ""
        line.isHidden = subtitle == nil
        line.textColor = color.withAlphaComponent(0.8)
        frame.size = fittingSize
    }
}
#endif

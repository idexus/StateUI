// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A caption that wraps stands as many lines tall as its words take at the width offered.
/// Design: docs/design/platforms/appkit/views.md#a-buttons-wrapped-caption
extension AppKitButtonView: AppKitWidthConstrainedMeasuring {
    /// The button's size `width` wide: a caption that wraps, wider than that, measured in the flexible push button's
    /// cell at it, its padding and its arrow's room kept; any other at AppKit's own size.
    func fittingContentSize(width: CGFloat?) -> NSSize {
        // The size stated in the tree stands in `fittingSize`; the caption's one line in `intrinsicContentSize` alone.
        let natural = fittingSize
        guard captionWraps, let width, width.isFinite, width < intrinsicContentSize.width,
              let cell = cell as? AppKitButtonCell else { return natural }
        let lines = Self.lines
        lines.attributedTitle = attributedTitle
        lines.image = image
        lines.imagePosition = imagePosition
        lines.lineBreakMode = cell.lineBreakMode
        let room = max(0, width - cell.padding.left - cell.padding.right - cell.arrowRoom)
        let words = lines.cellSize(forBounds: NSRect(x: 0, y: 0, width: room, height: 10_000))
        return NSSize(width: width, height: max(natural.height, words.height + cell.padding.top + cell.padding.bottom))
    }

    /// The cell a wrapping caption is measured in: the flexible push button's, as tall as its words stand.
    private static let lines: NSButtonCell = {
        let cell = NSButtonCell(textCell: "")
        cell.bezelStyle = .flexiblePush
        return cell
    }()
}
#endif

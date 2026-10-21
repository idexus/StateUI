// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// The arrow of a button holding a menu: a mark pointing down after its words, the whole button opening the menu; or
/// a split button's arrow, a part of its own at the trailing edge, set off by a line, opening the menu itself.
/// Design: docs/design/platforms/appkit/views.md#a-buttons-menu
@MainActor
struct AppKitButtonArrow {
    /// The mark, or the split button's arrow part.
    let view: NSView

    /// The line setting a split button's arrow apart; nil for a mark.
    let line: NSView?

    /// How wide the mark stands and how far after the words; how wide a split button's arrow part.
    static let markWidth: CGFloat = 10
    static let markGap: CGFloat = 6
    static let partWidth: CGFloat = 28

    /// The room the button keeps for the arrow at its trailing edge.
    var room: CGFloat {
        line == nil ? Self.markWidth + Self.markGap : Self.partWidth
    }

    /// The mark after the words of `button`, which takes no click of its own.
    static func mark(in button: NSView) -> Self {
        let mark = Mark()
        mark.image = chevron
        mark.imageScaling = .scaleProportionallyDown
        button.addSubview(mark)
        return Self(view: mark, line: nil)
    }

    /// A split button's arrow part in `button`, opening its menu as it is pressed.
    static func part(in button: AppKitButtonView) -> Self {
        let part = Part(button: button)
        let line = NSView()
        line.wantsLayer = true
        button.addSubview(line)
        button.addSubview(part)
        return Self(view: part, line: line)
    }

    /// Stands the arrow in `bounds`: a mark just after `content`, the words and picture as drawn; a split button's
    /// part at the trailing edge, the whole height, its line beside it.
    func place(in bounds: NSRect, after content: NSRect, rightToLeft: Bool) {
        guard let line else {
            let x = rightToLeft ? content.minX - Self.markGap - Self.markWidth : content.maxX + Self.markGap
            view.frame = NSRect(x: x, y: bounds.minY, width: Self.markWidth, height: bounds.height)
            return
        }
        let x = rightToLeft ? bounds.minX : bounds.maxX - Self.partWidth
        view.frame = NSRect(x: x, y: bounds.minY, width: Self.partWidth, height: bounds.height)
        let inset = (bounds.height / 4).rounded()
        line.frame = NSRect(
            x: rightToLeft ? bounds.minX + Self.partWidth : bounds.maxX - Self.partWidth - 1, y: bounds.minY + inset,
            width: 1, height: max(0, bounds.height - 2 * inset))
    }

    /// Draws the arrow in the words' color, and its line fainter.
    func tint(_ color: NSColor) {
        (view as? NSImageView)?.contentTintColor = color
        (view as? NSButton)?.contentTintColor = color
        line?.layer?.backgroundColor = color.withAlphaComponent(0.35).cgColor
    }

    private static var chevron: NSImage? {
        NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold))
    }

    /// A mark the pointer passes through to the button under it.
    private final class Mark: NSImageView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    /// A split button's arrow part: a menu button of its own, opening its button's menu as it is pressed.
    private final class Part: NSButton {
        private weak var button: AppKitButtonView?

        init(button: AppKitButtonView) {
            self.button = button
            super.init(frame: .zero)
            isBordered = false
            image = chevron
            imagePosition = .imageOnly
            // AppKit presents a button through its cell.
            cell?.setAccessibilityRole(.menuButton)
            cell?.setAccessibilityLabel("More")
            target = self
            action = #selector(pressed(_:))
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("AppKitButtonArrow's part is created in code")
        }

        /// The menu opens as the part is pressed, as AppKit's own pull-down opens.
        override func mouseDown(with event: NSEvent) {
            button?.showMenu()
        }

        @objc private func pressed(_ sender: Any?) {
            button?.showMenu()
        }
    }
}
#endif

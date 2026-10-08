// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension TextLook {
    /// The look as UIKit's text attributes: the font - `standing`'s where the look says none - the words' colour,
    /// what stands behind them, the space between the letters, a line's height, and the lines under or through them.
    func attributes(standing font: UIFont, color standingColor: UIColor) -> [NSAttributedString.Key: Any] {
        let shown = UIFont.stateUI(self, standing: font)
        var attributes: [NSAttributedString.Key: Any] = [
            .font: shown,
            .foregroundColor: color.flatMap(UIColor.init(stateUI:)) ?? standingColor,
        ]
        if let background = background.flatMap(UIColor.init(stateUI:)) { attributes[.backgroundColor] = background }
        if letterSpacing != 0 { attributes[.kern] = letterSpacing }
        if decorations.contains(.underline) { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if decorations.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if let lineHeight, lineHeight > 0 {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = lineHeight
            attributes[.paragraphStyle] = paragraph
        }
        return attributes
    }

    /// The look as a button's title takes it: its font, the space between its letters, and its colour where it says
    /// one - the button's own where it says none.
    func titleTransformer(standing font: UIFont, color standingColor: UIColor) -> UIConfigurationTextAttributesTransformer {
        let attributes = attributes(standing: font, color: standingColor)
        // The configuration keeps the transformer: it holds the look's values, never the button that holds it.
        let colored = color != nil
        return UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = attributes[.font] as? UIFont
            if colored { outgoing.foregroundColor = attributes[.foregroundColor] as? UIColor }
            if let kern = attributes[.kern] as? Double { outgoing.uiKit.kern = kern }
            return outgoing
        }
    }
}

extension UIEdgeInsets {
    /// StateUI's insets in UIKit's order.
    init(_ insets: Insets) {
        self.init(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right)
    }
}
#endif

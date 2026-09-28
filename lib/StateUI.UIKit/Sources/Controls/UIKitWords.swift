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
}

extension UIEdgeInsets {
    /// StateUI's insets in UIKit's order.
    init(_ insets: Insets) {
        self.init(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right)
    }
}
#endif

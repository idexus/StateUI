// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TextField: UIKit's own field on one line. The user's words are reported; the program's are only written.
@MainActor
final class UIKitTextFieldView: UITextField, UIKitTextInputView {
    let typing = UIKitTyping()
    let outline = UIKitFieldOutline()

    init() {
        super.init(frame: .zero)
        borderStyle = .roundedRect
        font = .stateUI(TextLook())
        adjustsFontForContentSizeCategory = true
        hearTyping()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        outline.draw(on: self, ownRadius: 0)
    }

    // MARK: - Outlined, its own frame laid aside

    /// How tall a field in UIKit's own rounded frame stands in this font and how far that frame sets its words in,
    /// for the font it was measured in: what an outlined field keeps.
    /// Design: docs/design/platforms/uikit/controls.md#a-fields-outline
    private var ownFrame: (font: UIFont?, height: CGFloat, inset: CGFloat) = (nil, 0, 0)

    private func measuredOwnFrame() -> (height: CGFloat, inset: CGFloat) {
        if ownFrame.font != font {
            let framed = UITextField()
            framed.borderStyle = .roundedRect
            framed.font = font
            let height = framed.sizeThatFits(CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude)).height
            ownFrame = (font, height, framed.textRect(forBounds: CGRect(x: 0, y: 0, width: 200, height: height)).minX)
        }
        return (ownFrame.height, ownFrame.inset)
    }

    /// `rect` set in from an outlined field's edge as its own frame sets it, and no less than half a round end.
    private func setIn(_ rect: CGRect) -> CGRect {
        guard outline.isDrawn else { return rect }
        return rect.insetBy(dx: max(measuredOwnFrame().inset, layer.cornerRadius / 2), dy: 0)
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect { setIn(super.textRect(forBounds: bounds)) }

    override func editingRect(forBounds bounds: CGRect) -> CGRect { setIn(super.editingRect(forBounds: bounds)) }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { setIn(super.placeholderRect(forBounds: bounds)) }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitted = super.sizeThatFits(size)
        guard outline.isDrawn else { return fitted }
        return CGSize(width: fitted.width, height: max(fitted.height, measuredOwnFrame().height))
    }

    override var intrinsicContentSize: CGSize {
        let own = super.intrinsicContentSize
        guard outline.isDrawn else { return own }
        return CGSize(width: own.width, height: max(own.height, measuredOwnFrame().height))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitTextFieldView is made in code")
    }

    func setLook(_ look: TextLook) {
        font = .stateUI(look, in: traitCollection)
        adjustsFontForContentSizeCategory = look.scales
        textColor = look.color.flatMap(UIColor.init(stateUI:)) ?? .label
    }
}
#endif

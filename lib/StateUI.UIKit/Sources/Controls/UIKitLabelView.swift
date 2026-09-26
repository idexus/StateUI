// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Label: a `UILabel`, its words standing across and down its room as the tree says.
@MainActor
final class UIKitLabelView: UILabel {
    /// Where the words stand down the room; a `UILabel` of itself stands them in its middle.
    private var verticalAlignment = TextAlignment.start {
        didSet { if verticalAlignment != oldValue { setNeedsDisplay() } }
    }

    /// Where the words stand across and down the room: a line's start and end follow the view's own direction.
    func setAlignment(horizontal: TextAlignment, vertical: TextAlignment) {
        textAlignment = switch horizontal {
        case .start: .natural
        case .center: .center
        case .end: effectiveUserInterfaceLayoutDirection == .rightToLeft ? .left : .right
        }
        verticalAlignment = vertical
    }

    private let madeFont: UIFont
    private let madeColor: UIColor?

    init() {
        madeFont = UIFont.preferredFont(forTextStyle: .body)
        madeColor = UIColor.label
        super.init(frame: .zero)
        font = madeFont
        numberOfLines = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitLabelView is made in code")
    }

    /// The words' look: the system's font and colour where it says nothing.
    func setLook(_ look: TextLook) {
        font = .stateUI(look, standing: madeFont)
        textColor = look.color.flatMap(UIColor.init(stateUI:)) ?? madeColor
    }

    /// How the words break, and how many lines show (`LineBreak.lines`).
    func setLines(breaking: LineBreak, maximum: Int?) {
        numberOfLines = breaking.lines(maximum: maximum) ?? 0
        lineBreakMode = switch breaking {
        case .noWrap: .byClipping
        case .wordWrap: .byWordWrapping
        case .characterWrap: .byCharWrapping
        case .headTruncation: .byTruncatingHead
        case .tailTruncation: .byTruncatingTail
        case .middleTruncation: .byTruncatingMiddle
        }
    }

    override func drawText(in rect: CGRect) {
        let fitted = textRect(forBounds: rect, limitedToNumberOfLines: numberOfLines)
        let top: CGFloat = switch verticalAlignment {
        case .start: rect.minY
        case .center: rect.minY + (rect.height - fitted.height) / 2
        case .end: rect.maxY - fitted.height
        }
        super.drawText(in: CGRect(x: rect.minX, y: top, width: rect.width, height: min(fitted.height, rect.height)))
    }
}
#endif

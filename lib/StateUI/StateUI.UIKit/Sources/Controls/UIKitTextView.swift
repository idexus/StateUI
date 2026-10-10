// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Text: a `UILabel` showing its words - or its spans' runs, each its own look over the label's - with their
/// look as attributes, standing across and down its room within its padding as the tree says.
/// Design: docs/design/platforms/uikit/controls.md#a-labels-words
@MainActor
final class UIKitTextView: UILabel {
    private var words = ""
    private var look = TextLook()
    private var runs: [TextRun]?
    private var horizontal = TextAlignment.start
    private var breaking = LineBreak.wordWrap

    /// The room between the label's edge and its words.
    private(set) var padding = UIEdgeInsets.zero

    /// What fills the label's box behind its words: a colour, or a brush; nothing where the tree says none.
    private var fill = UIKitBrush()

    /// Where the words stand down the room; a `UILabel` of itself stands them in its middle.
    private var verticalAlignment = TextAlignment.start {
        didSet { if verticalAlignment != oldValue { setNeedsDisplay() } }
    }

    init() {
        super.init(frame: .zero)
        font = .stateUI(TextLook())
        numberOfLines = 0
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (label: Self, _) in label.show() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitTextView is made in code")
    }

    /// The words, in their case.
    func setText(_ text: String) {
        words = text
        show()
    }

    /// Changes the words' look; what it leaves unsaid is the system's.
    func setLook(_ change: (inout TextLook) -> Void) {
        change(&look)
        show()
    }

    /// The spans' runs in place of the words; nil for the words again.
    func setRuns(_ runs: [TextRun]?) {
        self.runs = runs
        show()
    }

    /// The room between the label's edge and its words.
    func setPadding(_ insets: Insets?) {
        padding = insets.map(UIEdgeInsets.init) ?? .zero
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    /// Where the words stand across and down the room: a line's start and end follow the view's own direction.
    func setAlignment(horizontal: TextAlignment, vertical: TextAlignment) {
        self.horizontal = horizontal
        verticalAlignment = vertical
        show()
    }

    /// How the words break, and how many lines show (`LineBreak.lines`).
    func setLines(breaking: LineBreak, maximum: Int?) {
        self.breaking = breaking
        numberOfLines = breaking.lines(maximum: maximum) ?? 0
        show()
    }

    /// Writes the words - or the runs - with their look, then how the whole stands and breaks.
    private func show() {
        let standing = look.attributes(color: .label, in: traitCollection)
        let shown = NSMutableAttributedString()
        for run in runs ?? [TextRun(text: words, look: TextLook())] {
            shown.append(NSAttributedString(
                string: run.text, attributes: run.look.over(look).attributes(color: .label, in: traitCollection)))
        }
        attributedText = shown.length > 0 ? shown : NSAttributedString(string: "", attributes: standing)
        textAlignment = switch horizontal {
        case .start: .natural
        case .center: .center
        case .end: effectiveUserInterfaceLayoutDirection == .rightToLeft ? .left : .right
        }
        lineBreakMode = switch breaking {
        case .noWrap: .byClipping
        case .wordWrap: .byWordWrapping
        case .characterWrap: .byCharWrapping
        case .headTruncation: .byTruncatingHead
        case .tailTruncation: .byTruncatingTail
        case .middleTruncation: .byTruncatingMiddle
        }
        invalidateIntrinsicContentSize()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let room = CGSize(
            width: size.width.isFinite ? max(0, size.width - padding.left - padding.right) : size.width,
            height: size.height.isFinite ? max(0, size.height - padding.top - padding.bottom) : size.height)
        let fitted = super.sizeThatFits(room)
        return CGSize(
            width: fitted.width + padding.left + padding.right, height: fitted.height + padding.top + padding.bottom)
    }

    /// What fills the label's box behind its words: a colour as the view's own background, a brush painted before
    /// the words - they are the layer's own contents, which any layer added over it would cover.
    func setBackground(_ value: HostValue?) {
        let brush = HostBrush(value)
        if case .solid(let color) = brush {
            backgroundColor = UIColor(stateUI: color)
            fill = UIKitBrush()
        } else {
            backgroundColor = nil
            fill = UIKitBrush(value)
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext(), let painted = fill.layer(over: bounds, reusing: nil) {
            painted.render(in: context)
        }
        super.draw(rect)
    }

    override func drawText(in rect: CGRect) {
        let room = rect.inset(by: padding)
        let fitted = textRect(forBounds: room, limitedToNumberOfLines: numberOfLines)
        let top: CGFloat = switch verticalAlignment {
        case .start: room.minY
        case .center: room.minY + (room.height - fitted.height) / 2
        case .end: room.maxY - fitted.height
        }
        super.drawText(in: CGRect(x: room.minX, y: top, width: room.width, height: min(fitted.height, room.height)))
    }
}
#endif

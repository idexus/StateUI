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
final class UIKitTextView: UILabel, UIKitLabel, UIKitSteppable {
    /// What a reader's step performs, while the element says it is adjustable.
    var stepAction: ((AccessibilityAdjustment) -> Void)?

    override func accessibilityIncrement() { stepAction?(.increment) }

    override func accessibilityDecrement() { stepAction?(.decrement) }

    var shown = UIKitLabelWords()

    /// The room between the label's edge and its words.
    /// The room between the label's edge and its words, as the tree says it.
    private var insets = Insets(0)

    /// That room in UIKit's sides, by the direction the label lays out in.
    var padding: UIEdgeInsets { UIEdgeInsets(insets, in: semanticContentAttribute) }

    /// What fills the label's box behind its words: a colour, or a brush; nothing where the tree says none.
    private var fill = UIKitBrush()

    /// The words' sizes as measured for each width offered; the size measured without one holds in any wider room.
    /// Design: docs/design/host/layout.md#words-in-a-wider-room
    private let measurements = MeasurementCache(holdsWhenWider: true)
    private(set) var nativeMeasurementCountForTesting = 0

    /// The size the words were last drawn for: UIKit does not always draw a label again when its width alone
    /// changes, and its old drawing stands stretched to the new box until something else has it drawn.
    /// Design: docs/design/platforms/uikit/controls.md#a-labels-words
    private var drawnSize: CGSize?

    init() {
        super.init(frame: .zero)
        font = .stateUI(TextLook())
        numberOfLines = 0
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (label: Self, _) in label.showWords() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitTextView is made in code")
    }

    /// The room between the label's edge and its words.
    func setPadding(_ insets: Insets?) {
        self.insets = insets ?? Insets(0)
        directionTurned()
    }

    func directionTurned() {
        measurements.invalidate()
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    /// Writes the words - or the runs - with their look, then how the whole stands and breaks.
    func showWords() {
        attributedText = shown.attributed(in: traitCollection)
        textAlignment = shown.alignment(in: effectiveUserInterfaceLayoutDirection)
        lineBreakMode = shown.lineBreakMode
        numberOfLines = shown.lines
        measurements.invalidate()
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        // A layout measures with no bound below: the words' size for the width offered, kept.
        guard size.height >= .greatestFiniteMagnitude else { return fitted(size) }
        let width = size.width < .greatestFiniteMagnitude ? Double(size.width) : nil
        let measured = measurements.size(offering: width) {
            let words = self.fitted(size)
            return LayoutSize(width: words.width, height: words.height)
        }
        return CGSize(width: measured.width, height: measured.height)
    }

    /// The words' size within `size`, the padding around them.
    private func fitted(_ size: CGSize) -> CGSize {
        nativeMeasurementCountForTesting += 1
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

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != drawnSize { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        drawnSize = bounds.size
        if let context = UIGraphicsGetCurrentContext(), let painted = fill.layer(over: bounds, reusing: nil) {
            painted.render(in: context)
        }
        super.draw(rect)
    }

    override func drawText(in rect: CGRect) {
        let room = rect.inset(by: padding)
        let fitted = textRect(forBounds: room, limitedToNumberOfLines: numberOfLines)
        let top: CGFloat = switch shown.vertical {
        case .start: room.minY
        case .center: room.minY + (room.height - fitted.height) / 2
        case .end: room.maxY - fitted.height
        }
        super.drawText(in: CGRect(x: room.minX, y: top, width: room.width, height: min(fitted.height, room.height)))
    }
}
#endif

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Text whose words the user can select and copy: UIKit's text view, read only and not scrolling, showing the
/// words as a label does - a `UILabel` selects nothing.
/// Design: docs/design/platforms/uikit/controls.md#selectable-words
@MainActor
final class UIKitSelectableTextView: UITextView, UIKitLabel {
    var shown = UIKitLabelWords()

    /// The room between the view's edge and its words.
    private var padding = UIEdgeInsets.zero

    /// What fills the view's box behind its words where it is a brush, and the layer painting it.
    private var fill = UIKitBrush()
    private var painted: CALayer?

    /// Whether the words show as enabled: a disabled text selects nothing.
    var isEnabled = true {
        didSet { isSelectable = isEnabled }
    }

    init() {
        super.init(frame: .zero, textContainer: nil)
        isEditable = false
        isSelectable = true
        isScrollEnabled = false
        backgroundColor = nil
        textContainer.lineFragmentPadding = 0
        textContainerInset = .zero
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: Self, _) in view.showWords() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitSelectableTextView is made in code")
    }

    func setPadding(_ insets: Insets?) {
        padding = insets.map(UIEdgeInsets.init) ?? .zero
        standWords()
        invalidateIntrinsicContentSize()
    }

    func showWords() {
        attributedText = shown.attributed(in: traitCollection)
        textAlignment = shown.alignment(in: effectiveUserInterfaceLayoutDirection)
        textContainer.lineBreakMode = shown.lineBreakMode
        textContainer.maximumNumberOfLines = shown.lines
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func setBackground(_ value: HostValue?) {
        if case .solid(let color) = HostBrush(value) {
            backgroundColor = UIColor(stateUI: color)
            fill = UIKitBrush()
        } else {
            backgroundColor = nil
            fill = UIKitBrush(value)
        }
        setNeedsLayout()
    }

    /// The words' own size within `size`, and the padding around them - wherever down the room they stand.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitted = super.sizeThatFits(size)
        let lowered = textContainerInset.top - padding.top
        return CGSize(width: fitted.width, height: max(0, fitted.height - lowered))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        standWords()
        let fresh = fill.layer(over: bounds, reusing: painted)
        if fresh !== painted {
            painted?.removeFromSuperlayer()
            if let fresh { layer.insertSublayer(fresh, at: 0) }
            painted = fresh
        }
    }

    /// Stands the words down the room as the tree aligns them, within the padding.
    private func standWords() {
        let natural = super.sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height
            - textContainerInset.top - textContainerInset.bottom
        let free = max(0, bounds.height - padding.top - padding.bottom - natural)
        let lowered: CGFloat = switch shown.vertical {
        case .start: 0
        case .center: free / 2
        case .end: free
        }
        let inset = UIEdgeInsets(
            top: padding.top + lowered, left: padding.left, bottom: padding.bottom, right: padding.right)
        if textContainerInset != inset { textContainerInset = inset }
    }
}
#endif

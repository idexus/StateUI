// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TextEditor: UIKit's own text view of many lines, scrolling its words - or, growing with them, asking for their
/// whole height. What shows while there are no words is a label of its own over it, as a text view has none.
@MainActor
final class UIKitTextEditorView: UITextView, UIKitInputView {
    let typing = UIKitTyping()

    private let madeFont = UIFont.preferredFont(forTextStyle: .body)
    private let placeholderLabel = UILabel()

    init() {
        super.init(frame: .zero, textContainer: nil)
        font = madeFont
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 8
        delegate = typing
        placeholderLabel.font = madeFont
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        addSubview(placeholderLabel)
        NotificationCenter.default.addObserver(
            self, selector: #selector(wordsChanged), name: UITextView.textDidChangeNotification, object: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitTextEditorView is made in code")
    }

    var words: String { text }

    /// The words shown while there are none.
    var placeholder: String? { placeholderLabel.text }

    /// Whether the editor asks for the height of all its words rather than scrolling them.
    var growsWithText = false {
        didSet {
            isScrollEnabled = !growsWithText
            invalidateIntrinsicContentSize()
        }
    }

    func setText(_ words: String) {
        if text != words { text = words }
        wordsChanged()
    }

    func setPlaceholder(_ placeholder: String?, color: UIColor?) {
        placeholderLabel.text = placeholder
        placeholderLabel.textColor = color ?? .placeholderText
        setNeedsLayout()
    }

    /// Editable only while it takes input, as a text view made editable is made selectable too.
    func setBehaviour(enabled: Bool, readOnly: Bool, keyboard: UIKitKeyboard) {
        isEditable = enabled && !readOnly
        isSelectable = enabled
        keyboard.apply(to: self)
    }

    func setLook(_ look: TextLook) {
        font = .stateUI(look, standing: madeFont)
        placeholderLabel.font = font
        textColor = look.color.flatMap(UIColor.init(stateUI:)) ?? .label
    }

    func setAlignment(_ alignment: TextAlignment) {
        textAlignment = self.alignment(alignment)
        placeholderLabel.textAlignment = textAlignment
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard growsWithText else { return CGSize(width: size.width.isFinite ? size.width : 0, height: 0) }
        return super.sizeThatFits(size)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = textContainerInset
        let padding = textContainer.lineFragmentPadding
        let width = bounds.width - inset.left - inset.right - padding * 2
        let fitted = placeholderLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        placeholderLabel.frame = CGRect(x: inset.left + padding, y: inset.top, width: width, height: fitted.height)
    }

    @objc private func wordsChanged() {
        placeholderLabel.isHidden = !text.isEmpty
        if growsWithText { invalidateIntrinsicContentSize() }
    }
}
#endif

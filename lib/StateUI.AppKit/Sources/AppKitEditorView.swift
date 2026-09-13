// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A native multiline editor whose scroll ownership stays inside the control.
@MainActor
final class AppKitEditorView: NSView, NSTextViewDelegate {
    let scrollView = NSScrollView()
    let textView = NSTextView()
    private let placeholder = AppKitEditorPlaceholder()

    var onTextChanged: ((String) -> Void)?
    var onCompleted: (() -> Void)?
    private(set) var maxLength: Int?

    private var writing = false
    private var growsWithText = false
    private var cursorPosition: Int?
    private var selectionLength: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView

        textView.delegate = self
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude)

        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.lineBreakMode = .byTruncatingTail
        placeholder.maximumNumberOfLines = 1

        addSubview(scrollView)
        addSubview(placeholder)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            placeholder.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            placeholder.topAnchor.constraint(equalTo: topAnchor, constant: 7),
        ])
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitEditorView is created in code")
    }

    override var intrinsicContentSize: NSSize {
        guard growsWithText else {
            return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }

        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let used = layoutManager.usedRect(for: textContainer)
            let inset = textView.textContainerInset.height * 2
            let line = textView.font?.boundingRectForFont.height ?? 17
            return NSSize(
                width: NSView.noIntrinsicMetric,
                height: ceil(max(used.height, line) + inset + 2))
        }

        return NSSize(width: NSView.noIntrinsicMetric, height: 24)
    }

    func apply(
        text: String?,
        writeText: Bool,
        placeholder placeholderText: String?,
        placeholderColor: NSColor?,
        foregroundColor: NSColor,
        backgroundColor: NSColor?,
        font: NSFont,
        horizontalAlignment: Int32?,
        enabled: Bool,
        readOnly: Bool,
        maximumLength: Int?,
        spellChecking: Bool,
        textPrediction: Bool,
        cursorPosition: Int?,
        selectionLength: Int?,
        growsWithText: Bool
    ) {
        maxLength = maximumLength.map { max(0, $0) }
        self.growsWithText = growsWithText
        self.cursorPosition = cursorPosition
        self.selectionLength = selectionLength

        textView.textColor = foregroundColor
        textView.backgroundColor = backgroundColor ?? .textBackgroundColor
        textView.drawsBackground = true
        textView.font = font
        textView.alignment = nativeAlignment(horizontalAlignment)
        textView.isEditable = enabled && !readOnly
        textView.isSelectable = enabled
        textView.isContinuousSpellCheckingEnabled = spellChecking
        textView.isAutomaticTextCompletionEnabled = textPrediction

        scrollView.hasVerticalScroller = !growsWithText
        placeholder.stringValue = placeholderText ?? ""
        placeholder.textColor = placeholderColor ?? .placeholderTextColor
        placeholder.font = font
        placeholder.alignment = nativeAlignment(horizontalAlignment)

        if writeText, let text { setText(text) }

        updatePlaceholder()
        applySelection()
        invalidateIntrinsicContentSize()
    }

    func setText(_ text: String) {
        guard textView.string != text else { return }
        writing = true
        textView.string = text
        writing = false
        updatePlaceholder()
        applySelection()
        invalidateIntrinsicContentSize()
    }

    func textDidChange(_ notification: Notification) {
        guard !writing else { return }
        let typed = limited(textView.string)

        if typed != textView.string {
            writing = true
            textView.string = typed
            textView.selectedRange = NSRange(location: typed.utf16.count, length: 0)
            writing = false
        }

        updatePlaceholder()
        invalidateIntrinsicContentSize()
        onTextChanged?(typed)
    }

    func textDidEndEditing(_ notification: Notification) {
        onCompleted?()
    }

    private func updatePlaceholder() {
        placeholder.isHidden = !textView.string.isEmpty
    }

    private func applySelection() {
        guard cursorPosition != nil || selectionLength != nil else { return }
        let words = textView.string
        let start = utf16Offset(of: max(0, cursorPosition ?? 0), in: words)
        let end = utf16Offset(
            of: max(0, cursorPosition ?? 0) + max(0, selectionLength ?? 0),
            in: words)
        textView.selectedRange = NSRange(location: start, length: max(0, end - start))
    }

    private func limited(_ text: String) -> String {
        guard let maxLength, text.count > maxLength else { return text }
        return String(text.prefix(maxLength))
    }

    private func utf16Offset(of characterOffset: Int, in text: String) -> Int {
        let offset = min(characterOffset, text.count)
        let index = text.index(text.startIndex, offsetBy: offset)
        return index.utf16Offset(in: text)
    }

    private func nativeAlignment(_ value: Int32?) -> NSTextAlignment {
        switch value {
        case 1: return .center
        case 2: return userInterfaceLayoutDirection == .rightToLeft ? .left : .right
        default: return userInterfaceLayoutDirection == .rightToLeft ? .right : .left
        }
    }

    var placeholderForTesting: String { placeholder.stringValue }

    func typeForTesting(_ text: String) {
        textView.string = text
        textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
    }

    func completeForTesting() {
        textDidEndEditing(Notification(name: NSText.didEndEditingNotification, object: textView))
    }
}

private final class AppKitEditorPlaceholder: NSTextField {
    convenience init() {
        self.init(labelWithString: "")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

#endif

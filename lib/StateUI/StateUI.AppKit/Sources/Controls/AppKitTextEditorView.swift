// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A native multiline editor whose scroll ownership stays inside the control.
@MainActor
final class AppKitTextEditorView: NSView, NSTextViewDelegate {
    /// What the editor's keyboard and its checking of the words do.
    private(set) var traits = InputTraits(spellChecked: true, predicted: true, purpose: nil)

    let scrollView = NSScrollView()
    let textView = NSTextView()
    private let placeholder = AppKitTextEditorPlaceholder()

    var onTextChanged: ((String) -> Void)?
    private(set) var maximumLength: Int?

    /// The case the view holds its words in; nil for as they are typed.
    var textCase: TextCase?

    private var growsWithText = false
    private var cursorPosition: Int?
    private var selectionLength: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        // Rounded as a field's bezel is, its words set in from the edge.
        // Design: docs/design/platforms/appkit/registrations.md#a-background
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = Self.cornerRadius
        scrollView.layer?.masksToBounds = true
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
        textView.textContainerInset = Self.inset
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
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset.width + 3),
            placeholder.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.inset.width - 3),
            placeholder.topAnchor.constraint(equalTo: topAnchor, constant: Self.inset.height),
        ])
    }

    /// The corners' radius, a rounded field's.
    static let cornerRadius: CGFloat = 6

    /// How far the words stand in from the editor's edge.
    static let inset = NSSize(width: 4, height: 5)

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitTextEditorView is created in code")
    }

    override var intrinsicContentSize: NSSize {
        guard growsWithText else {
            return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }
        return NSSize(width: NSView.noIntrinsicMetric, height: grownHeight(at: nil))
    }

    /// The height of the words laid out at `width` - the editor's own where none is offered - a line at the least,
    /// with the text's insets around them.
    private func grownHeight(at width: CGFloat?) -> CGFloat {
        let font = textView.font ?? .systemFont(ofSize: NSFont.systemFontSize)
        let line = font.boundingRectForFont.height
        let sides = (textView.textContainer?.lineFragmentPadding ?? 0) * 2 + textView.textContainerInset.width * 2
        let room = (width ?? bounds.width) - sides
        let words = NSAttributedString(string: textView.string, attributes: [.font: font])
        let used = room > 0
            ? words.boundingRect(
                with: NSSize(width: room, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]).height
            : line
        return ceil(max(used, line) + textView.textContainerInset.height * 2)
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
        traits: InputTraits,
        cursorPosition: Int?,
        selectionLength: Int?,
        writeSelection: Bool,
        growsWithText: Bool
    ) {
        self.maximumLength = maximumLength.map { max(0, $0) }
        self.growsWithText = growsWithText
        self.cursorPosition = cursorPosition
        self.selectionLength = selectionLength

        textView.textColor = foregroundColor
        // A colour with an alpha lets what lies behind the editor through.
        textView.backgroundColor = backgroundColor ?? .textBackgroundColor
        textView.drawsBackground = true
        scrollView.drawsBackground = backgroundColor == nil
        textView.font = font
        textView.alignment = nativeAlignment(horizontalAlignment)
        textView.isEditable = enabled && !readOnly
        textView.isSelectable = enabled
        self.traits = traits
        textView.take(traits)

        scrollView.hasVerticalScroller = !growsWithText
        placeholder.stringValue = placeholderText ?? ""
        placeholder.textColor = placeholderColor ?? .placeholderTextColor
        placeholder.font = font
        placeholder.alignment = nativeAlignment(horizontalAlignment)

        if writeText, let text { setText(text) }

        updatePlaceholder()
        if writeSelection { applySelection() }
        invalidateMeasurements()
    }

    func setText(_ text: String) {
        guard textView.string != text else { return }
        ProgramWrite.perform {
            textView.string = text
        }
        updatePlaceholder()
        invalidateMeasurements()
    }

    func textDidChange(_ notification: Notification) {
        guard !ProgramWrite.isWriting else { return }
        let typed = InputWords.held(textView.string, in: textCase, toBound: maximumLength) ?? textView.string

        if typed != textView.string {
            ProgramWrite.perform {
                textView.string = typed
                textView.selectedRange = NSRange(location: typed.utf16.count, length: 0)
            }
        }

        updatePlaceholder()
        invalidateMeasurements()
        onTextChanged?(typed)
    }

    /// The text checking the user's typing runs follows the editor's traits.
    func textView(
        _ view: NSTextView, willCheckTextIn range: NSRange, options: [NSSpellChecker.OptionKey: Any] = [:],
        types checkingTypes: UnsafeMutablePointer<NSTextCheckingTypes>
    ) -> [NSSpellChecker.OptionKey: Any] {
        traits.checking(options)
    }

    private func updatePlaceholder() {
        placeholder.isHidden = !textView.string.isEmpty
    }

    /// Only a change of the authored selection moves the caret. A text write,
    /// including the one that carries the user's own typing back, leaves
    /// the caret where the user put it.
    private func applySelection() {
        guard cursorPosition != nil || selectionLength != nil else { return }
        let words = textView.string
        let selection = InputWords.utf16Selection(
            start: cursorPosition ?? 0, length: selectionLength ?? 0, in: words)
        textView.selectedRange = NSRange(location: selection.start, length: selection.length)
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

}

private final class AppKitTextEditorPlaceholder: NSTextField {
    convenience init() {
        self.init(labelWithString: "")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// A growing editor stands as tall as its words at the width offered; a fixed one as AppKit measures it.
extension AppKitTextEditorView: AppKitWidthConstrainedMeasuring {
    func fittingContentSize(width: CGFloat?) -> NSSize {
        let native = fittingSize
        return growsWithText ? NSSize(width: native.width, height: grownHeight(at: width)) : native
    }
}

extension AppKitTextEditorView: AppKitAccessibilityPresenting {
    var presentedControl: NSView { textView }
}

#endif

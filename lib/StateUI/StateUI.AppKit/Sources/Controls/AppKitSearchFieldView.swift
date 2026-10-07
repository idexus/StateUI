// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// AppKit's native search field with separate edit and submit reports.
@MainActor
final class AppKitSearchFieldView: NSSearchField, NSSearchFieldDelegate {
    var onTextChanged: ((String) -> Void)?
    var onSubmitted: (() -> Void)?
    private(set) var maximumLength: Int?

    /// The case the view holds its words in; nil for as they are typed.
    var textCase: TextCase?

    /// What the search's keyboard and its checking of the words do.
    private(set) var traits = InputTraits(spellChecked: true, predicted: true, purpose: nil)
    private var cursorPosition: Int?
    private var selectionLength: Int?

    /// The colour the field stands on, in the search field's capsule; nil for AppKit's own bezel.
    private(set) var fill: NSColor?

    override class var cellClass: AnyClass? {
        get { AppKitSearchFieldCell.self }
        set {}
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        delegate = self
        target = self
        action = #selector(submitted(_:))
        sendsWholeSearchString = true
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitSearchFieldView is created in code")
    }

    func apply(
        text: String?,
        writeText: Bool,
        placeholder: String?,
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
        writeSelection: Bool
    ) {
        self.maximumLength = maximumLength.map { max(0, $0) }
        self.traits = traits
        self.cursorPosition = cursorPosition
        self.selectionLength = selectionLength

        placeholderString = nil
        placeholderAttributedString = nil
        if let placeholderColor, let placeholder {
            placeholderAttributedString = .placeholder(
                placeholder, color: placeholderColor, alignment: nativeAlignment(horizontalAlignment))
        } else {
            placeholderString = placeholder
        }

        textColor = foregroundColor
        self.font = font
        isEnabled = enabled
        isEditable = !readOnly
        isSelectable = true
        isAutomaticTextCompletionEnabled = traits.predicts
        alignment = nativeAlignment(horizontalAlignment)

        // AppKit's bezel draws its own ground over any colour: a field given one stands in the bezel's capsule,
        // filled with it, its words and buttons set in as the bezel sets them.
        // Design: docs/design/platforms/appkit/registrations.md#a-background
        let colored = backgroundColor.map { $0.alphaComponent > 0 } ?? false
        fill = colored ? backgroundColor : nil
        (cell as? AppKitSearchFieldCell)?.isBoxed = colored
        isBordered = false
        isBezeled = !colored
        drawsBackground = false
        wantsLayer = true
        layer?.backgroundColor = fill?.cgColor
        layer?.cornerRadius = colored ? bounds.height / 2 : 0
        noteFocusRingMaskChanged()
        invalidateIntrinsicContentSize()

        if writeText, let text { setText(text) }

        applyEditorPreferences()
        if writeSelection { applySelection() }
    }

    override var intrinsicContentSize: NSSize {
        var own = super.intrinsicContentSize
        if fill != nil { own.height += AppKitSearchFieldCell.inset.height * 2 }
        return own
    }

    override func layout() {
        super.layout()
        if fill != nil { layer?.cornerRadius = bounds.height / 2 }
    }

    override func drawFocusRingMask() {
        guard fill != nil else { return super.drawFocusRingMask() }
        NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
    }

    override var focusRingMaskBounds: NSRect { fill != nil ? bounds : super.focusRingMaskBounds }

    func setText(_ text: String) {
        guard stringValue != text else { return }
        ProgramWrite.perform {
            stringValue = text
            currentEditor()?.string = text
        }
    }

    func controlTextDidBeginEditing(_ notification: Notification) {
        applyEditorPreferences()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard !ProgramWrite.isWriting else { return }
        let typed = InputWords.held(stringValue, in: textCase, toBound: maximumLength) ?? stringValue

        if typed != stringValue {
            ProgramWrite.perform {
                stringValue = typed
                if let editor = currentEditor() {
                    editor.string = typed
                    editor.selectedRange = NSRange(location: typed.utf16.count, length: 0)
                }
            }
        }

        onTextChanged?(typed)
    }

    @objc private func submitted(_ sender: NSSearchField) {
        onSubmitted?()
    }

    private func applyEditorPreferences() {
        guard let editor = currentEditor() as? NSTextView else { return }
        editor.take(traits)
    }

    /// The search is its editor's delegate: the text checking the user's typing runs follows its traits.
    @objc(textView:willCheckTextInRange:options:types:)
    func textView(
        _ view: NSTextView, willCheckTextIn range: NSRange, options: [NSSpellChecker.OptionKey: Any],
        types: UnsafeMutablePointer<NSTextCheckingTypes>
    ) -> [NSSpellChecker.OptionKey: Any] {
        traits.checking(options)
    }

    /// Only a change of the authored selection moves the caret. A text write,
    /// including the one that carries the user's own typing back, leaves
    /// the caret where the user put it.
    private func applySelection() {
        guard let editor = currentEditor(),
              cursorPosition != nil || selectionLength != nil
        else { return }

        let words = editor.string
        let selection = InputWords.utf16Selection(
            start: cursorPosition ?? 0, length: selectionLength ?? 0, in: words)
        editor.selectedRange = NSRange(location: selection.start, length: selection.length)
    }



    private func nativeAlignment(_ value: Int32?) -> NSTextAlignment {
        switch value {
        case 1:
            return .center
        case 2:
            return userInterfaceLayoutDirection == .rightToLeft ? .left : .right
        default:
            return userInterfaceLayoutDirection == .rightToLeft ? .right : .left
        }
    }

    var placeholderStringForTesting: String? {
        placeholderAttributedString?.string ?? placeholderString
    }

    func typeForTesting(_ text: String) {
        stringValue = text
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    }

    func submitForTesting() {
        submitted(self)
    }
}

/// A search field's cell that, standing in a filled capsule with no bezel, sets its magnifier, its words and its
/// cancel button where the bezel sets them along the field, across the middle of its height - drawn and edited.
@MainActor
final class AppKitSearchFieldCell: NSSearchFieldCell {
    /// Whether the field stands in a filled capsule rather than AppKit's bezel.
    var isBoxed = false

    /// How far the capsule sets the field's parts in from its top and bottom edges.
    static let inset = NSSize(width: 0, height: 4)

    override func searchButtonRect(forBounds rect: NSRect) -> NSRect {
        centred(super.searchButtonRect(forBounds: rect), in: rect)
    }

    override func cancelButtonRect(forBounds rect: NSRect) -> NSRect {
        centred(super.cancelButtonRect(forBounds: rect), in: rect)
    }

    override func searchTextRect(forBounds rect: NSRect) -> NSRect {
        words(super.searchTextRect(forBounds: rect), in: rect)
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        words(super.drawingRect(forBounds: rect), in: rect)
    }

    // AppKit lays the editor of a field with no bezel over its whole frame: a boxed field hands it the words' room.
    override func select(
        withFrame rect: NSRect, in controlView: NSView, editor: NSText, delegate: Any?, start: Int, length: Int
    ) {
        super.select(
            withFrame: isBoxed ? searchTextRect(forBounds: rect) : rect, in: controlView, editor: editor,
            delegate: delegate, start: start, length: length)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(
            withFrame: isBoxed ? searchTextRect(forBounds: rect) : rect, in: controlView, editor: editor,
            delegate: delegate, event: event)
    }

    /// `part` moved across the middle of `rect`'s height, where the field stands boxed.
    private func centred(_ part: NSRect, in rect: NSRect) -> NSRect {
        guard isBoxed else { return part }
        var moved = part
        moved.origin.y = rect.minY + ((rect.height - part.height) / 2).rounded()
        return moved
    }

    /// The words' room `along` the field, one line high across the middle of `rect`, where the field stands boxed.
    private func words(_ along: NSRect, in rect: NSRect) -> NSRect {
        guard isBoxed else { return along }
        let line = (font ?? .systemFont(ofSize: NSFont.systemFontSize)).boundingRectForFont.height.rounded(.up)
        return NSRect(x: along.minX, y: rect.minY + ((rect.height - line) / 2).rounded(), width: along.width, height: line)
    }
}

#endif

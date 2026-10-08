// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A native single-line text field that can change between ordinary and
/// secure AppKit editors without changing the StateUI element's identity.
@MainActor
final class AppKitTextFieldView: NSView, NSTextFieldDelegate {
    private(set) var textField: NSTextField
    private(set) var isSecure = false
    private(set) var maximumLength: Int?

    /// The case the view holds its words in; nil for as they are typed.
    var textCase: TextCase?

    var onTextChanged: ((String) -> Void)?
    var onSubmitted: (() -> Void)?

    /// What the field's keyboard and its checking of the words do.
    private var traits = InputTraits(spellChecked: true, predicted: true, purpose: nil)
    private var cursorPosition: Int?
    private var selectionLength: Int?

    override init(frame frameRect: NSRect) {
        textField = AppKitWordsField()
        super.init(frame: frameRect)
        install(textField)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitTextFieldView is created in code")
    }

    /// The colour the field stands on, in a rounded field's shape; nil for AppKit's own bezel.
    private(set) var fill: NSColor?

    /// How far a field standing on a colour sets its words in from its edge, as the rounded bezel does.
    static let inset = NSSize(width: 6, height: 4)

    override var intrinsicContentSize: NSSize {
        let own = textField.intrinsicContentSize
        guard fill != nil else { return own }
        let width = own.width == NSView.noIntrinsicMetric ? own.width : own.width + Self.inset.width * 2
        return NSSize(width: width, height: own.height + Self.inset.height * 2)
    }

    override func layout() {
        super.layout()
        guard fill != nil else {
            textField.frame = bounds
            (textField as? AppKitBoxedField)?.ringBox = nil
            return
        }
        let height = textField.intrinsicContentSize.height
        textField.frame = NSRect(
            x: Self.inset.width, y: ((bounds.height - height) / 2).rounded(),
            width: max(0, bounds.width - Self.inset.width * 2), height: height)
        (textField as? AppKitBoxedField)?.ringBox = convert(bounds, to: textField)
    }

    /// Applies the StateUI properties that have direct AppKit semantics.
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
        secure: Bool,
        maximumLength: Int?,
        traits: InputTraits,
        cursorPosition: Int?,
        selectionLength: Int?,
        writeSelection: Bool
    ) {
        if secure != isSecure {
            replaceTextField(secure: secure)
        }

        self.maximumLength = maximumLength.map { max(0, $0) }
        self.traits = traits
        (textField as? AppKitWordsField)?.traits = traits
        self.cursorPosition = cursorPosition
        self.selectionLength = selectionLength

        textField.placeholderString = nil
        textField.placeholderAttributedString = nil

        if let placeholderColor, let placeholder {
            textField.placeholderAttributedString = .placeholder(
                placeholder, color: placeholderColor, alignment: alignment(horizontalAlignment))
        } else {
            textField.placeholderString = placeholder
        }

        textField.textColor = foregroundColor
        textField.font = font
        textField.isEnabled = enabled
        textField.isEditable = !readOnly
        textField.isSelectable = true
        textField.isAutomaticTextCompletionEnabled = traits.predicts
        textField.alignment = alignment(horizontalAlignment)

        // AppKit's rounded bezel draws its own ground over any colour: a field given one stands in the bezel's
        // shape, filled with it. A border and a bezel exclude each other: the border is said first, so the bezel
        // said after it stands. Design: docs/design/platforms/appkit/registrations.md#a-background
        let colored = backgroundColor.map { $0.alphaComponent > 0 } ?? false
        fill = colored ? backgroundColor : nil
        textField.isBordered = false
        textField.isBezeled = !colored
        textField.bezelStyle = .roundedBezel
        textField.drawsBackground = false
        wantsLayer = true
        layer?.backgroundColor = fill?.cgColor
        layer?.cornerRadius = colored ? AppKitTextEditorView.cornerRadius : 0
        needsLayout = true

        if writeText, let text {
            setText(text)
        }

        applyEditorPreferences()
        if writeSelection { applySelection() }
        invalidateMeasurements()
    }

    /// Writes text from StateUI without turning that write into a user report.
    func setText(_ text: String) {
        guard textField.stringValue != text else { return }

        ProgramWrite.perform {
            textField.stringValue = text

            if let editor = textField.currentEditor() {
                editor.string = text
            }

        }
        invalidateMeasurements()
    }

    func controlTextDidBeginEditing(_ notification: Notification) {
        applyEditorPreferences()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard !ProgramWrite.isWriting else { return }

        let typed = InputWords.held(textField.stringValue, in: textCase, toBound: maximumLength) ?? textField.stringValue

        if typed != textField.stringValue {
            ProgramWrite.perform {
                textField.stringValue = typed

                if let editor = textField.currentEditor() {
                    editor.string = typed
                    editor.selectedRange = NSRange(location: typed.utf16.count, length: 0)
                }

            }
        }

        onTextChanged?(typed)
    }

    @objc func submitted(_ sender: NSTextField) {
        onSubmitted?()
    }

    private func install(_ field: NSTextField) {
        field.delegate = self
        field.target = self
        field.action = #selector(submitted(_:))
        field.maximumNumberOfLines = 1
        field.translatesAutoresizingMaskIntoConstraints = true
        field.autoresizingMask = [.width, .height]
        addSubview(field)
    }

    private func replaceTextField(secure: Bool) {
        let previous = textField
        let words = previous.stringValue
        let wasFirstResponder = window?.firstResponder === previous.currentEditor()
            || window?.firstResponder === previous
        let replacement: NSTextField = secure ? AppKitSecureWordsField() : AppKitWordsField()

        previous.removeFromSuperview()
        textField = replacement
        isSecure = secure
        install(replacement)
        replacement.frame = bounds
        replacement.stringValue = words

        if wasFirstResponder {
            window?.makeFirstResponder(replacement)
        }
    }

    private func applyEditorPreferences() {
        guard let editor = textField.currentEditor() as? NSTextView else { return }

        editor.take(traits)
    }

    /// Only a change of the authored selection moves the caret. A text write,
    /// including the one that carries the user's own typing back, leaves
    /// the caret where the user put it.
    private func applySelection() {
        guard let editor = textField.currentEditor(),
              cursorPosition != nil || selectionLength != nil
        else { return }

        let text = editor.string
        let selection = InputWords.utf16Selection(
            start: cursorPosition ?? 0, length: selectionLength ?? 0, in: text)
        editor.selectedRange = NSRange(location: selection.start, length: selection.length)
    }



    func typeForTesting(_ text: String) {
        textField.stringValue = text
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    }

    private func alignment(_ value: Int32?) -> NSTextAlignment {
        switch value {
        case 1:
            return .center
        case 2:
            return userInterfaceLayoutDirection == .rightToLeft ? .left : .right
        default:
            return userInterfaceLayoutDirection == .rightToLeft ? .right : .left
        }
    }
}

extension AppKitTextFieldView: AppKitAccessibilityPresenting {
    var presentedControl: NSView { textField }
}

#endif

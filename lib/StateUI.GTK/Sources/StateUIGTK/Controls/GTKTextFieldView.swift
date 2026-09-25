// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A TextField: a `GtkEntry` on one line, whose words reach Swift as they change and whose Enter submits. The
/// words stand in the entry's `GtkText`, which the search field's entry holds too.
/// Design: docs/design/platforms/gtk/controls.md#a-field-and-its-words
@MainActor
class GTKTextFieldView: GTKView, GTKInputView {
    /// What the field does when its words change, handed all of them.
    var onTextChanged: ((String) -> Void)?

    /// What the field does when the user presses Enter in it.
    var onSubmitted: (() -> Void)?

    private var wordsClass: String?

    convenience init() {
        self.init { gtk_entry_new() }
    }

    init(_ make: () -> GTKWidget?) {
        super.init { _ in make() }
        connect("changed") { _, data in
            MainActor.assumeIsolated {
                guard let view = GTKView.find(viewNumber(data)) as? GTKTextFieldView else { return }
                view.onTextChanged?(view.text)
            }
        }
        connect("activate") { _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKTextFieldView)?.onSubmitted?() }
        }
    }

    private var editable: OpaquePointer { widget.opaque }

    /// The entry's own text widget: its words, their bound and what the input method is told.
    private var words: UnsafeMutablePointer<GtkText> { UnsafeMutablePointer(gtk_editable_get_delegate(editable)) }

    var text: String {
        String(cString: gtk_editable_get_text(editable))
    }

    func setText(_ text: String) {
        guard text != self.text else { return }
        gtk_editable_set_text(editable, text)
        gtk_editable_set_position(editable, -1)
    }

    func setPlaceholder(_ placeholder: String?) {
        gtk_text_set_placeholder_text(words, placeholder)
    }

    func setMaximumLength(_ length: Int?) {
        gtk_text_set_max_length(words, Int32(clamping: length ?? 0))
    }

    /// Whether the words are shown or each hidden behind a dot.
    func setPassword(_ hidden: Bool) {
        gtk_text_set_visibility(words, hidden ? 0 : 1)
    }

    func setBehaviour(readOnly: Bool, hints: GtkInputHints, purpose: GtkInputPurpose) {
        gtk_editable_set_editable(editable, readOnly ? 0 : 1)
        gtk_text_set_input_hints(words, hints)
        gtk_text_set_input_purpose(words, purpose)
    }

    func setAlignment(_ alignment: TextAlignment) {
        gtk_editable_set_alignment(editable, alignment == .start ? 0 : alignment == .center ? 0.5 : 1)
    }

    func setWordsClass(_ name: String?) {
        swapClass(&wordsClass, to: name)
    }

    func select(start: Int, length: Int) {
        let start = Int32(clamping: max(0, start))
        gtk_editable_select_region(editable, start, start + Int32(clamping: max(0, length)))
    }

    override func detach() {
        super.detach()
        onTextChanged = nil
        onSubmitted = nil
    }
}

/// A SearchField: a `GtkSearchEntry` - its search icon, a button clearing it, and its Enter submitting - holding
/// its words as a field does.
/// Design: docs/design/platforms/gtk/controls.md#a-search-field
@MainActor
final class GTKSearchFieldView: GTKTextFieldView {
    init() {
        super.init { gtk_search_entry_new() }
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A TextField: a `GtkEntry` on one line, whose words reach Swift as they change and whose Enter submits. The
/// words stand in the entry's `GtkText`, which the search field's entry holds too.
/// Design: docs/design/platforms/gtk/controls.md#a-field-and-its-words
@MainActor
class GTKTextFieldView: GTKView, GTKTextInputView {
    /// What the field does when its words change, handed all of them.
    var onTextChanged: ((String) -> Void)?
    var outlineClass: String?

    /// What the field does when the user presses Enter in it.
    var onSubmitted: (() -> Void)?

    private var wordsClass: String?
    private var maximumLength: Int?
    private var textCase: TextCase?

    /// The caret and the selection the program put, which stand over the field's first focus; nil once that has
    /// passed or the user has changed the words.
    private var programCaret: (start: Int, length: Int)?

    convenience init() {
        self.init { gtk_entry_new() }
    }

    init(_ make: () -> GTKWidget?) {
        super.init { _ in make() }
        connect("changed") { _, data in
            MainActor.assumeIsolated {
                guard let view = GTKView.find(viewNumber(data)) as? GTKTextFieldView else { return }
                if !ProgramWrite.isWriting { view.programCaret = nil }
                view.onTextChanged?(view.text)
            }
        }
        let focus = gtk_event_controller_focus_new()!
        connectSignal(UnsafeMutableRawPointer(focus), "enter", number: number) {
            (_: UnsafeMutableRawPointer?, data: gpointer?) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKTextFieldView)?.focused() }
        }
        gtk_widget_add_controller(widget, focus)
        connect("activate") { _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKTextFieldView)?.onSubmitted?() }
        }
        connectSignal(UnsafeMutableRawPointer(words), "insert-text", number: number) {
            (_: UnsafeMutableRawPointer?, typed: UnsafePointer<CChar>?, bytes: Int32, place: UnsafeMutablePointer<Int32>?,
             data: gpointer?) in
            MainActor.assumeIsolated {
                (GTKView.find(viewNumber(data)) as? GTKTextFieldView)?.inserting(typed, bytes, at: place)
            }
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
        self.placeholder = placeholder
        gtk_text_set_placeholder_text(words, placeholder)
        invalidateMeasure()
    }

    /// The words shown while there are none - which a field nothing sizes is at least as wide as.
    private var placeholder: String?

    /// GTK's entry, at least twenty digits and its placeholder wide in its font, with what the entry draws around
    /// its words (`FieldWidth`); no wider than offered nor narrower than GTK's least.
    /// Design: docs/design/host/layout.md#a-fields-own-width
    override func measure(width: Double?, height: Double?) -> LayoutSize {
        let measured = super.measure(width: nil, height: height)
        var (least, natural): (Int32, Int32) = (0, 0)
        gtk_widget_measure(widget, GTK_ORIENTATION_HORIZONTAL, -1, &least, &natural, nil, nil)
        var (wordsLeast, wordsNatural): (Int32, Int32) = (0, 0)
        gtk_widget_measure(words.of(GtkWidget.self), GTK_ORIENTATION_HORIZONTAL, -1, &wordsLeast, &wordsNatural, nil, nil)
        let leastWords = FieldWidth.leastWords(placeholder: placeholder).map { said -> Double in
            let layout = gtk_widget_create_pango_layout(words.of(GtkWidget.self), said)
            defer { g_object_unref(layout.map(UnsafeMutableRawPointer.init)) }
            var pixels: Int32 = 0
            pango_layout_get_pixel_size(layout, &pixels, nil)
            return Double(pixels)
        }
        let wide = FieldWidth.width(own: Double(natural), measured: leastWords, chrome: Double(natural - wordsNatural))
        let across = width.map { max(Double(least), min(wide, $0.rounded(.down))) } ?? wide
        return LayoutSize(width: across, height: measured.height)
    }

    /// The most characters the words take. GTK's own bound counts code points, so the host cuts what goes in.
    func setMaximumLength(_ length: Int?) {
        maximumLength = length
    }

    /// The case the words stand in. GTK holds none, so the host turns what goes in into it.
    func setTextCase(_ textCase: TextCase?) {
        self.textCase = textCase
    }

    /// Words going in at `place`, a scalar's offset: in the field's case, and where they would take the field past its
    /// bound only the first characters that fit there (`InputWords.fitting`) - from a key, a paste and a program's
    /// write alike.
    private func inserting(_ typed: UnsafePointer<CChar>?, _ bytes: Int32, at place: UnsafeMutablePointer<Int32>?) {
        guard let typed else { return }
        let inserted = bytes < 0
            ? String(cString: typed) : String(decoding: UnsafeRawBufferPointer(start: typed, count: Int(bytes)), as: UTF8.self)
        guard let fitting = InputWords.fitting(
            inserted, beside: text, atScalar: place.map { Int($0.pointee) }, in: textCase, toBound: maximumLength)
        else { return }
        g_signal_stop_emission_by_name(UnsafeMutableRawPointer(words), "insert-text")
        guard !fitting.isEmpty else { return }
        gtk_editable_insert_text(OpaquePointer(words), fitting, -1, place)
    }

    /// Whether the words are shown or each hidden behind a dot.
    func setPassword(_ hidden: Bool) {
        gtk_text_set_visibility(words, hidden ? 0 : 1)
    }

    func setBehavior(readOnly: Bool, hints: GtkInputHints, purpose: GtkInputPurpose) {
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

    func setTabularDigits(_ tabular: Bool) {
        let words = UnsafeMutablePointer<GtkText>(gtk_editable_get_delegate(editable))
        guard tabular else { return gtk_text_set_attributes(words, nil) }
        let list = pango_attr_list_new()
        defer { pango_attr_list_unref(list) }
        pango_attr_list_insert(list, pango_attr_font_features_new("tnum 1"))
        gtk_text_set_attributes(words, list)
    }

    /// Puts the caret `start` characters in and selects `length` from it, in the scalars GTK counts
    /// (`InputWords.scalarSelection`).
    func select(start: Int, length: Int) {
        if ProgramWrite.isWriting { programCaret = (start, length) }
        let scalars = InputWords.scalarSelection(start: start, length: length, in: text)
        gtk_editable_select_region(
            editable, Int32(clamping: scalars.start), Int32(clamping: scalars.start + scalars.length))
    }

    /// The field took the focus: GNOME has selected its words whole, and the program's caret, where it put one,
    /// stands again - once.
    /// Design: docs/design/platforms/gtk/controls.md#a-field-and-its-words
    private func focused() {
        guard programCaret != nil else { return }
        GTKRenderer.afterLayout { [weak self] in
            guard let self, let caret = self.programCaret else { return }
            self.programCaret = nil
            ProgramWrite.perform { self.select(start: caret.start, length: caret.length) }
            self.programCaret = nil
        }
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

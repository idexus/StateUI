// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A TextEditor: a `GtkTextView` of wrapped lines, whose Enter starts a new one, in a `GtkScrolledWindow` -
/// growing with its words, or keeping a line's height and scrolling them.
/// Design: docs/design/platforms/gtk/controls.md#an-editor
@MainActor
final class GTKTextEditorView: GTKView, GTKInputView {
    var onTextChanged: ((String) -> Void)?

    /// Whether the editor takes the height of its words.
    private(set) var growsWithText = false

    private let editor: GTKWidget
    private let placeholder: GTKWidget
    private var maximumLength: Int?
    private var wordsClass: String?

    init() {
        editor = gtk_text_view_new()
        placeholder = gtk_label_new(nil)
        super.init { _ in gtk_scrolled_window_new() }
        gtk_scrolled_window_set_child(widget.opaque, editor)
        gtk_scrolled_window_set_policy(widget.opaque, GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_widget_add_css_class(widget, GTKStyleSheet.editor)
        gtk_text_view_set_wrap_mode(view, GTK_WRAP_WORD_CHAR)
        gtk_text_view_set_left_margin(view, Self.margin.across)
        gtk_text_view_set_right_margin(view, Self.margin.across)
        gtk_text_view_set_top_margin(view, Self.margin.down)
        gtk_text_view_set_bottom_margin(view, Self.margin.down)

        for name in ["dim-label", Self.placeholderClass] { gtk_widget_add_css_class(placeholder, name) }
        gtk_widget_set_can_target(placeholder, 0)
        gtk_widget_set_visible(placeholder, 0)
        gtk_text_view_add_overlay(view, placeholder, Self.margin.across, 0)

        connectSignal(UnsafeMutableRawPointer(buffer), "changed", number: number) { _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKTextEditorView)?.changed() }
        }
        connectSignal(UnsafeMutableRawPointer(buffer), "insert-text", number: number) { buffer, place, words, bytes, data in
            MainActor.assumeIsolated {
                (GTKView.find(viewNumber(data)) as? GTKTextEditorView)?.inserting(words, bytes, at: place)
            }
        }
    }

    /// The room between the editor's edge and its words: an entry's.
    private static let margin = (across: Int32(9), down: Int32(8))

    /// The class the placeholder wears, which a placeholder colour's rule names.
    static let placeholderClass = "stateui-placeholder"

    private var view: UnsafeMutablePointer<GtkTextView> { editor.of() }
    private var buffer: UnsafeMutablePointer<GtkTextBuffer> { gtk_text_view_get_buffer(view) }

    var text: String {
        var start = GtkTextIter()
        var end = GtkTextIter()
        gtk_text_buffer_get_bounds(buffer, &start, &end)
        guard let words = gtk_text_buffer_get_text(buffer, &start, &end, 0) else { return "" }
        defer { g_free(words) }
        return String(cString: words)
    }

    func setText(_ text: String) {
        guard text != self.text else { return }
        gtk_text_buffer_set_text(buffer, text, -1)
        var end = GtkTextIter()
        gtk_text_buffer_get_end_iter(buffer, &end)
        gtk_text_buffer_place_cursor(buffer, &end)
    }

    func setPlaceholder(_ placeholder: String?) {
        gtk_label_set_text(self.placeholder.opaque, placeholder ?? "")
        showPlaceholder()
    }

    func setMaximumLength(_ length: Int?) {
        maximumLength = length
    }

    func setBehaviour(readOnly: Bool, hints: GtkInputHints, purpose: GtkInputPurpose) {
        gtk_text_view_set_editable(view, readOnly ? 0 : 1)
        gtk_text_view_set_input_hints(view, hints)
        gtk_text_view_set_input_purpose(view, purpose)
    }

    func setAlignment(_ alignment: TextAlignment) {
        gtk_text_view_set_justification(
            view, alignment == .start ? GTK_JUSTIFY_LEFT : alignment == .center ? GTK_JUSTIFY_CENTER : GTK_JUSTIFY_RIGHT)
    }

    func setWordsClass(_ name: String?) {
        swapClass(&wordsClass, to: name, on: editor)
        invalidateMeasure()
    }

    func select(start: Int, length: Int) {
        var from = GtkTextIter()
        var to = GtkTextIter()
        gtk_text_buffer_get_iter_at_offset(buffer, &from, Int32(clamping: max(0, start)))
        gtk_text_buffer_get_iter_at_offset(buffer, &to, Int32(clamping: max(0, start) + max(0, length)))
        gtk_text_buffer_select_range(buffer, &to, &from)
    }

    func setGrowsWithText(_ grows: Bool) {
        guard grows != growsWithText else { return }
        growsWithText = grows
        invalidateMeasure()
    }

    /// As wide as the room offered, its words wrapping in it; growing, as tall as they are, and not, as tall as a
    /// line of them, whatever it holds - the room its layout gives it is the room it scrolls in. Never shorter than
    /// GTK's least for its scrolled window, its scrollbar's length.
    /// Design: docs/design/platforms/gtk/controls.md#an-editor
    override func measure(width: Double?, height: Double?) -> LayoutSize {
        let across = width?.rounded(.down) ?? super.measure(width: nil, height: nil).width
        var least: Int32 = 0
        var words: Int32 = 0
        gtk_widget_measure(editor, GTK_ORIENTATION_VERTICAL, Int32(across), &least, &words, nil, nil)
        let own = growsWithText ? words : lineHeight
        gtk_widget_measure(widget, GTK_ORIENTATION_VERTICAL, Int32(across), &least, &words, nil, nil)
        return LayoutSize(width: across, height: Double(max(own, least)))
    }

    /// One line of words in the editor's font, with the room above and below them.
    private var lineHeight: Int32 {
        let layout = gtk_widget_create_pango_layout(editor, "X")
        defer { g_object_unref(layout.map(UnsafeMutableRawPointer.init)) }
        var height: Int32 = 0
        pango_layout_get_pixel_size(layout, nil, &height)
        return height + 2 * Self.margin.down
    }

    /// The words changed: the placeholder shown only while there are none, and the words handed on.
    private func changed() {
        showPlaceholder()
        onTextChanged?(text)
    }

    /// Words going in at `place`: where they would take the editor past its bound, only the first that fit go in,
    /// as a field's text takes them - from a key, a paste and a program's write alike.
    private func inserting(_ words: UnsafePointer<CChar>?, _ bytes: Int32, at place: UnsafeMutablePointer<GtkTextIter>?) {
        guard let maximumLength, let words, bytes > 0 else { return }
        let inserted = String(decoding: UnsafeRawBufferPointer(start: words, count: Int(bytes)), as: UTF8.self)
        let room = max(0, maximumLength - Int(gtk_text_buffer_get_char_count(buffer)))
        guard inserted.unicodeScalars.count > room else { return }
        g_signal_stop_emission_by_name(UnsafeMutableRawPointer(buffer), "insert-text")
        guard room > 0 else { return }
        gtk_text_buffer_insert(buffer, place, String(String.UnicodeScalarView(inserted.unicodeScalars.prefix(room))), -1)
    }

    private func showPlaceholder() {
        let label = gtk_label_get_text(placeholder.opaque).map { String(cString: $0) } ?? ""
        gtk_widget_set_visible(placeholder, gtk_text_buffer_get_char_count(buffer) == 0 && !label.isEmpty ? 1 : 0)
    }

    override func detach() {
        super.detach()
        onTextChanged = nil
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import StateUIConformance
import XCTest

/// A field and an editor sharing words a button rewrites, each telling what it hears.
private struct RewrittenPage: View {
    @State private var words = "one"
    let heard: Received<String>

    var body: some View {
        let heard = self.heard
        return VStack {
            TextField($words).onTextChanged { heard.values.append("field \($0)") }
            TextEditor($words).onTextChanged { heard.values.append("editor \($0)") }
            Button("Rewrite").onClicked { words = "two" }
        }
    }
}

@MainActor
final class GTKTextInputViewTests: XCTestCase {
    /// GNOME selects a field's words whole as it takes the focus: a caret or a selection the program put there stands
    /// over the field's first focus - and once the user has acted in the field, GNOME's own way stands.
    func testTheProgramsCaretOutlastsTheFieldsFirstFocus() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Button("First")
                    TextField(State(wrappedValue: "abcdefg").projectedValue).cursorPosition(2).selectionLength(3)
                }
            }
            let field = try XCTUnwrap(host.views(GTKTextFieldView.self).first)
            let editable = field.widget.opaque

            gtk_widget_grab_focus(field.widget)
            host.settle { false }

            var (start, end): (Int32, Int32) = (0, 0)
            _ = gtk_editable_get_selection_bounds(editable, &start, &end)
            XCTAssertEqual([start, end], [2, 5], "the program's selection, not GNOME's whole")
            gtk_editable_select_region(editable, 0, -1)
            gtk_widget_grab_focus(host.views(GTKButtonView.self)[0].widget)
            gtk_widget_grab_focus(field.widget)
            host.settle { false }
            _ = gtk_editable_get_selection_bounds(editable, &start, &end)
            XCTAssertEqual([start, end], [0, 7], "once the user has been there, GNOME's own")
        }
    }

    /// Typing stops at the most characters allowed - an emoji one character, whole or not at all - in a field and an
    /// editor alike.
    func testTypingStopsAtTheMostCharactersAllowed() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    TextField(State(wrappedValue: "").projectedValue).maximumLength(2)
                    TextEditor(State(wrappedValue: "").projectedValue).maximumLength(2)
                }
            }
            let field = try XCTUnwrap(host.views(GTKTextFieldView.self).first)
            let editor = try XCTUnwrap(host.views(GTKTextEditorView.self).first)

            GTKTestHost.emit(gtk_editable_get_delegate(field.widget.opaque), "insert-at-cursor", words: "a👍🏽b")
            GTKTestHost.emit(
                OpaquePointer(gtk_scrolled_window_get_child(editor.widget.opaque)), "insert-at-cursor", words: "a👍🏽b")

            XCTAssertEqual(field.text, "a👍🏽")
            XCTAssertEqual(editor.text, "a👍🏽")
        }
    }

    /// What the user types stands in the field's case, and its state hears it so - in a field and an editor alike.
    func testTypedWordsStandInTheFieldsCase() throws {
        try onUIThread {
            let (upper, lower) = (State(wrappedValue: ""), State(wrappedValue: ""))
            let host = GTKRenderer.running {
                VStack {
                    TextField(upper.projectedValue).textCase(.uppercase)
                    TextEditor(lower.projectedValue).textCase(.lowercase)
                }
            }
            let field = try XCTUnwrap(host.views(GTKTextFieldView.self).first)
            let editor = try XCTUnwrap(host.views(GTKTextEditorView.self).first)

            GTKTestHost.emit(gtk_editable_get_delegate(field.widget.opaque), "insert-at-cursor", words: "Ada")
            GTKTestHost.emit(OpaquePointer(gtk_scrolled_window_get_child(editor.widget.opaque)), "insert-at-cursor", words: "Ada")
            host.settle { upper.wrappedValue == "ADA" && lower.wrappedValue == "ada" }

            XCTAssertEqual([field.text, editor.text], ["ADA", "ada"])
            XCTAssertEqual([upper.wrappedValue, lower.wrappedValue], ["ADA", "ada"])
        }
    }

    /// A field's placeholder, coloured or not, stands across the field where its words do.
    func testAPlaceholderStandsWhereTheWordsDo() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    TextField(State(wrappedValue: "").projectedValue).placeholder("Scan")
                        .placeholderColor(Color("#FF0000")).horizontalTextAlignment(.center).width(300)
                    TextField(State(wrappedValue: "").projectedValue).placeholder("Name").horizontalTextAlignment(.end)
                        .width(300)
                }
            }
            host.layOut()
            // The placeholder is a label across the field's words; where its words stand in it is its alignment.
            let placed = host.views(GTKTextFieldView.self).map { field -> Float? in
                GTKTestHost.descendants(of: field.widget).first {
                    GTKTestHost.holds($0, gtk_label_get_type()) && gtk_widget_get_mapped($0) != 0
                }.map { gtk_label_get_xalign($0.opaque) }
            }
            XCTAssertEqual(placed, [0.5, 1], "the centred field's, the end-aligned field's")
        }
    }

    /// Words the program writes into a field or an editor stand there and are heard by nobody: only the user's are.
    func testTheProgramsWordsAreHeardByNobody() throws {
        try onUIThread {
            let heard = Received<String>()
            let host = GTKRenderer.running { RewrittenPage(heard: heard) }
            let field = try XCTUnwrap(host.views(GTKTextFieldView.self).first)
            let editor = try XCTUnwrap(host.views(GTKTextEditorView.self).first)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { field.text == "two" && editor.text == "two" }

            XCTAssertEqual([field.text, editor.text], ["two", "two"])
            XCTAssertEqual(heard.values, [], "heard by nobody")
        }
    }

    /// A field takes words as the tree says: read only, unchecked, unpredicted, for an address, centred, hidden,
    /// and its caret and selection where they were put; GTK's own where the tree says nothing.
    func testAFieldTakesWordsAsTheTreeSays() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    TextField("abcdefg")
                        .isReadOnly(true)
                        .isSpellCheckEnabled(false)
                        .isTextPredictionEnabled(false)
                        .inputPurpose(.email)
                        .horizontalTextAlignment(.center)
                        .isPassword(true)
                        .cursorPosition(2)
                        .selectionLength(3)
                    TextField("")
                }
            }
            let fields = host.views(GTKTextFieldView.self)

            XCTAssertEqual(fields[0].facts, [
                "read only", "hints \(GTK_INPUT_HINT_NO_SPELLCHECK.rawValue)",
                "purpose \(GTK_INPUT_PURPOSE_EMAIL.rawValue)", "alignment 0.5", "hidden", "selected 2-5",
            ])
            XCTAssertEqual(fields[1].facts, [
                "editable", "hints 0", "purpose \(GTK_INPUT_PURPOSE_FREE_FORM.rawValue)", "alignment 0.0", "shown",
                "selected 0-0",
            ])
        }
    }

    /// Typed words take their font and colour, and the placeholder its own colour in full, where GTK dims it.
    func testTypedWordsTakeTheirFontAndColour() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    TextField("").placeholder("MMM").placeholderColor(Color("#FF0000")).fontSize(40)
                        .fontAttributes(.bold).width(200)
                    TextField("MMM").textColor(Color("#0000FF")).fontSize(40).fontAttributes(.bold).width(200)
                    TextField("MMM").width(200)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let fields = host.views(GTKTextFieldView.self)
            host.settle { fields[0].shows(0xFFFF_0000) }

            XCTAssertTrue(fields[0].shows(0xFFFF_0000), "the placeholder red, not dimmed")
            XCTAssertTrue(fields[1].shows(0xFF00_00FF), "the words blue")
            XCTAssertGreaterThan(fields[1].frame.height, fields[2].frame.height + 10, "at 40 pixels")
        }
    }

    /// An editor's placeholder shows only while it holds no words.
    func testAnEditorsPlaceholderShowsOnlyWhileItHoldsNoWords() throws {
        try onUIThread {
            let host = GTKRenderer.running { VStack { TextEditor("").placeholder("Notes") } }
            let editor = try XCTUnwrap(host.views(GTKTextEditorView.self).first)
            XCTAssertTrue(editor.showsPlaceholder)

            editor.type("one")
            host.runtime.pump.turn()

            XCTAssertFalse(editor.showsPlaceholder)
        }
    }

    /// An editor growing with its words takes their height; one that does not keeps a line's - no less than its
    /// scrollbar's length - however many it holds.
    func testAnEditorGrowsWithItsWordsOnlyWhereItIsToldTo() throws {
        try onUIThread {
            let words = State(wrappedValue: "one")
            let host = GTKRenderer.running {
                VStack {
                    TextEditor(words.projectedValue).growsWithText(true).width(200)
                    TextEditor(words.projectedValue).width(200)
                    Button("More").onClicked { words.wrappedValue = "one\ntwo\nthree\nfour\nfive" }
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let editors = host.views(GTKTextEditorView.self)
            let before = editors.map(\.frame.height)
            XCTAssertEqual(before[0], before[1], "one line in both")

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { editors[0].frame.height > before[0] + 40 }

            XCTAssertGreaterThan(editors[0].frame.height, before[0] + 40, "grown with its words")
            XCTAssertEqual(editors[1].frame.height, before[1], "a line's height, however many it holds")
        }
    }

}

private extension GTKTextFieldView {
    /// What GTK holds of the field: whether it takes words, the input method's hints and purpose, the words'
    /// alignment, whether they show, and the selection.
    var facts: [String] {
        let words = UnsafeMutablePointer<GtkText>(gtk_editable_get_delegate(widget.opaque))
        var start: Int32 = 0
        var end: Int32 = 0
        _ = gtk_editable_get_selection_bounds(widget.opaque, &start, &end)
        return [
            gtk_editable_get_editable(widget.opaque) != 0 ? "editable" : "read only",
            "hints \(gtk_text_get_input_hints(words).rawValue)",
            "purpose \(gtk_text_get_input_purpose(words).rawValue)",
            "alignment \(gtk_editable_get_alignment(widget.opaque))",
            gtk_text_get_visibility(words) != 0 ? "shown" : "hidden",
            "selected \(start)-\(end)",
        ]
    }
}

private extension GTKView {
    /// Whether GTK draws the colour `argb` anywhere on the widget, looked for every two pixels.
    func shows(_ argb: UInt32) -> Bool {
        let size = frame
        let points = stride(from: 0.0, to: size.width, by: 2).flatMap { x in
            stride(from: 0.0, to: size.height, by: 2).map { y in (x, y) }
        }
        return pixels(at: points).contains(argb)
    }
}

private extension GTKTextEditorView {
    /// Changes the editor's words as the user's typing does: written outside a program's write.
    func type(_ words: String) {
        let editor = gtk_scrolled_window_get_child(widget.opaque)!
        gtk_text_buffer_set_text(gtk_text_view_get_buffer(editor.of()), words, -1)
    }

    /// Whether the editor's placeholder shows.
    var showsPlaceholder: Bool {
        GTKTestHost.descendants(of: widget).contains { label in
            GTKTestHost.classes(of: label).contains(GTKTextEditorView.placeholderClass)
                && gtk_widget_get_visible(label) != 0
        }
    }
}

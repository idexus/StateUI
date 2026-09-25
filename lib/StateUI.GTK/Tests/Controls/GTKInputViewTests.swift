// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

final class GTKInputViewTests: XCTestCase {
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
            host.pump.turn()

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

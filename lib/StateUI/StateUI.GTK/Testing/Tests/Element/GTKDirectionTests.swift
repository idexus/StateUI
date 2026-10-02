// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

/// Controls whose words stand in parts of their own, in the direction a switch gives them.
private struct WritingControls: View {
    @Binding var direction: LayoutDirection
    @State private var words = "abc"
    @State private var count = 3.0

    var body: some View {
        VStack {
            TextField($words)
            SearchField($words)
            Stepper($count)
            TextEditor($words)
            Button("Next").icon("test_dot.png")
        }
        .layoutDirection(direction)
    }
}

final class GTKDirectionTests: XCTestCase {
    /// GTK hands a widget's direction to none of its parts: the words a field, a search field and a stepper edit, an
    /// editor's text and a button's picture and caption take the element's own, and turn with it.
    func testTheWritingPartsTakeTheElementsDirection() throws {
        try onUIThread {
            let direction = State(wrappedValue: LayoutDirection.rightToLeft)
            let host = GTKRenderer.running { WritingControls(direction: direction.projectedValue) }
            XCTAssertEqual(try Self.parts(in: host), Array(repeating: GTK_TEXT_DIR_RTL, count: 5))

            direction.wrappedValue = .leftToRight
            host.step()

            XCTAssertEqual(try Self.parts(in: host), Array(repeating: GTK_TEXT_DIR_LTR, count: 5))
        }
    }

    /// The direction of each part that writes: the fields' and the stepper's text, the editor's, the button's box.
    @MainActor
    private static func parts(in host: GTKRenderer) throws -> [GtkTextDirection] {
        let editables = host.views(GTKTextFieldView.self).map { $0.widget } + host.views(GTKStepperView.self).map { $0.widget }
        let words = try editables.map { try XCTUnwrap(gtk_editable_get_delegate($0.opaque)) }
        let editor = try XCTUnwrap(host.views(GTKTextEditorView.self).first)
        let button = try XCTUnwrap(host.views(GTKButtonView.self).first)
        let writing = words.map { UnsafeMutablePointer<GtkWidget>($0) }
            + [try XCTUnwrap(gtk_scrolled_window_get_child(editor.widget.opaque)),
               try XCTUnwrap(gtk_button_get_child(button.widget.of(GtkButton.self)))]
        return writing.map { gtk_widget_get_direction($0) }
    }
}

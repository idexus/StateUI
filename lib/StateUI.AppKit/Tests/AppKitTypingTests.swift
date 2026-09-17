// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// What the reader types stays where it was typed. A keystroke reports the
/// field's whole text, and the render that report causes writes the field
/// back from the value it carries - never from the one before it, which would
/// put every field one keystroke behind the reader.
final class AppKitTypingTests: XCTestCase {
    @MainActor
    func testEveryBoundTextControlKeepsEachKeystroke() throws {
        let form = TypingForm()
        stateUIUseApp(TypingApp(form: form))
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.startForTesting()

        let content = try XCTUnwrap(renderer.windowsForTesting.first?.window?.contentView)
        let field = try XCTUnwrap(Self.first(AppKitTextFieldView.self, in: content))
        let editor = try XCTUnwrap(Self.first(AppKitTextEditorView.self, in: content))
        let search = try XCTUnwrap(Self.first(AppKitSearchFieldView.self, in: content))

        for typed in ["a", "ad", "ada"] {
            field.typeForTesting(typed)
            renderer.pump()
            XCTAssertEqual(field.textField.stringValue, typed, "the field")

            editor.typeForTesting(typed)
            renderer.pump()
            XCTAssertEqual(editor.textView.string, typed, "the editor")

            search.typeForTesting(typed)
            renderer.pump()
            XCTAssertEqual(search.stringValue, typed, "the search field")
        }

        XCTAssertEqual(form.name, "ada")
        XCTAssertEqual(form.notes, "ada")
        XCTAssertEqual(form.query, "ada")
    }

    @MainActor
    private static func first<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for child in view.subviews {
            if let match = first(type, in: child) { return match }
        }
        return nil
    }
}

/// The three texts the test types into.
private final class TypingForm {
    @State var name = ""
    @State var notes = ""
    @State var query = ""
}

private struct TypingWindow: Window {
    let form: TypingForm

    var page: any Page {
        VStack {
            TextField(form.$name)
            TextEditor(form.$notes)
            SearchField(form.$query)
        }
    }
}

private struct TypingApp: Application {
    let form: TypingForm

    var scene: any Scene { TypingWindow(form: form) }
}
#endif

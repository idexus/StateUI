// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

/// A greeting over a field, as HelloWorld's page has it.
func greeting(name: State<String>, maximumLength: Int = 40) -> any Page {
    VStack {
        Label(name.wrappedValue.isEmpty ? "Hello!" : "Hello, \(name.wrappedValue)!")
        TextField(name.projectedValue)
            .placeholder("Type your name")
            .maximumLength(maximumLength)
    }
}

final class GTKTextFieldViewTests: XCTestCase {
    /// Each keystroke is the field's words so far and one letter more, as UI Automation sets them.
    func testEachKeystrokeReachesTheStateAndStaysTyped() throws {
        try onUIThread {
            let name = State(wrappedValue: "")
            let host = GTKRenderer.running { greeting(name: name) }
            let field = try XCTUnwrap(host.views(GTKTextFieldView.self).first)

            for letter in ["A", "d", "a"] {
                field.type(field.text + letter)
            }

            XCTAssertEqual(name.wrappedValue, "Ada")
            XCTAssertEqual(field.text, "Ada")
            XCTAssertEqual(host.views(GTKLabelView.self).map(\.text), ["Hello, Ada!"])
        }
    }

    func testTypingStopsAtTheMaximumLength() throws {
        try onUIThread {
            let name = State(wrappedValue: "")
            let host = GTKRenderer.running { greeting(name: name, maximumLength: 3) }
            let field = try XCTUnwrap(host.views(GTKTextFieldView.self).first)

            field.type("Ada")
            field.type("Adam")

            XCTAssertEqual(name.wrappedValue, "Ada")
            XCTAssertEqual(field.text, "Ada")
        }
    }

    func testAStateWriteShowsTheWordsAndIsNotHeardAsTyping() throws {
        try onUIThread {
            let name = State(wrappedValue: "")
            let typed = Received<String>()
            let host = GTKRenderer.running {
                VStack {
                    TextField(name.projectedValue).onTextChanged { typed.values.append($0) }
                    Button("Ada").onClicked { name.wrappedValue = "Ada" }
                }
            }
            let field = try XCTUnwrap(host.views(GTKTextFieldView.self).first)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()

            XCTAssertEqual(field.text, "Ada")
            XCTAssertEqual(typed.values, [])
        }
    }
}

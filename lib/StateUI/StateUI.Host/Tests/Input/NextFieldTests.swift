// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How every host hands the keyboard on from a field whose return says Next: to the next field its page reads.
@MainActor
final class NextFieldTests: XCTestCase {
    private func element(
        _ id: String, _ type: NodeType, next: Bool = false, enabled: Bool = true, shown: Bool = true,
        _ children: [HostPatch] = []
    ) -> HostPatch {
        var element = HostPatch(id: .manual(id), type: type)
        if next { element.properties[.submitLabel] = SubmitLabel.next.propValue }
        if !enabled { element.properties[.isEnabled] = .bool(false) }
        if !shown { element.properties[.isVisible] = .bool(false) }
        if !children.isEmpty { element.children = .arranged(children) }
        return element
    }

    /// A page reading: a name, a row of a disabled field and a hidden one beside a street, a search, a note, a
    /// field before a page of its own holding a field, and the last field.
    private func page() throws -> MountedElement {
        let page = element("page", .page, [
            element("form", .vStack, [
                element("name", .textField, next: true),
                element("row", .hStack, [
                    element("off", .textField, enabled: false),
                    element("hidden", .textField, shown: false),
                    element("street", .textField, next: true),
                ]),
                element("label", .text),
                element("search", .searchField, next: true),
                element("note", .textEditor),
                element("before", .textField, next: true),
                element("inner", .page, [element("elsewhere", .textField, next: true)]),
                element("last", .textField, next: true),
            ]),
        ])
        runtime.tree.apply(page, complete: true)
        return try XCTUnwrap(runtime.tree.root)
    }

    private let runtime = HostRuntime.still()

    /// A presenter recording where it put the keyboard.
    private final class Focusing: HostPresenter {
        var focused: [ElementID] = []
        func presentRendered(touchedChrome: Bool) {}
        func presentFrame(movedChrome: Bool) {}
        func perform(_ call: HostActCall) {}
        func open(link address: String) {}
        func focus(_ element: MountedElement) { focused.append(element.id) }
    }

    private func named(_ id: String, in root: MountedElement) throws -> MountedElement {
        try XCTUnwrap(root.first(id: .manual(id)), id)
    }

    func testTheKeyboardGoesOnToTheNextFieldInReadingOrder() throws {
        let page = try page()
        XCTAssertEqual(NextField.after(try named("name", in: page))?.id, .manual("street"),
                       "a disabled field and a hidden one are passed by, and a row read in order")
        XCTAssertEqual(NextField.after(try named("street", in: page))?.id, .manual("search"), "past what is no field")
        XCTAssertEqual(NextField.after(try named("search", in: page))?.id, .manual("note"), "an editor is a field")
    }

    func testAPageOfItsOwnIsNotRead() throws {
        let page = try page()
        XCTAssertEqual(NextField.after(try named("before", in: page))?.id, .manual("last"),
                       "the field on a page inside is that page's")
        XCTAssertNil(NextField.after(try named("elsewhere", in: page)), "a page inside reads only itself")
    }

    func testTheLastFieldAndOneWithNoNextKeepTheKeyboard() throws {
        let page = try page()
        XCTAssertNil(NextField.after(try named("last", in: page)), "the last field hands it to none")
        XCTAssertNil(NextField.after(try named("note", in: page)), "a field whose return says no Next keeps it")
    }

    /// A field whose return says Next, submitted, has its host put the keyboard on the next field; one whose return
    /// says no Next leaves it where it is.
    func testASubmittedFieldHandsTheKeyboardOn() throws {
        let page = try page()
        let presenter = Focusing()
        runtime.presenter = presenter

        try named("name", in: page).send(.submitted, [], in: runtime)
        try named("note", in: page).send(.submitted, [], in: runtime)

        XCTAssertEqual(presenter.focused, [.manual("street")])
    }
}

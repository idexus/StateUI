// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// The fields, realized through the registry, and the silence they keep: a text
/// the host CARRIES IN is the host's to write, so the tree's own words are not
/// put on the control beside it.
///
/// What a field does as a reader types in it is held to
/// `AppKitTextFieldViewTests`, `AppKitTextEditorViewTests` and
/// `AppKitSearchFieldViewTests`, which drive these same registered views.
final class AppKitFieldRegistrationTests: XCTestCase {
    /// The registry realizes all three fields: the words each carries, the
    /// change each reports, and the members they take from the tiers they wear.
    @MainActor
    func testTheRegistryRealizesTheFields() {
        let realization = AppKitRegistrations.registry.realization

        XCTAssertTrue(realization.elements.isSuperset(of: ["TextField", "TextEditor", "SearchField"]))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "TextField", owner: "TextElement", member: "text")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "TextField", owner: "InputView", member: "textChanged")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "TextField", owner: "TextField", member: "submitted")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "TextEditor", owner: "TextEditor", member: "growsWithText")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "SearchField", owner: "InputView", member: "placeholder")))
    }

    /// `StateMode.in` says the host writes the value and this side only reads
    /// it back - a field fed from the platform. Text described beside such a
    /// binding is not written onto the control: the control is the source.
    @MainActor
    func testAFieldWhoseTextIsCarriedInIsNotWrittenFromTheTree() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var entry = HostPatch(id: .manual("entry"), type: .textField)
        entry.properties[.text] = .string("from the tree")
        entry.driven = .replace([.text: HostStateBinding(state: 5, mode: .in, kind: .text)])
        renderer.applyForTesting(tree(entry))

        let view = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("entry")) as? AppKitTextFieldView)

        XCTAssertEqual(
            view.textField.stringValue, "",
            "a text carried in is the host's to write, and the tree's words are not put over it")
    }

    /// The other side of the same rule: where nothing carries the text, the
    /// tree's words ARE the field's, and a later patch that changes them
    /// reaches the control.
    @MainActor
    func testAFieldNothingCarriesTakesTheTreesWords() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var entry = HostPatch(id: .manual("entry"), type: .textField)
        entry.properties[.text] = .string("Ada")
        renderer.applyForTesting(tree(entry))

        let view = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("entry")) as? AppKitTextFieldView)
        XCTAssertEqual(view.textField.stringValue, "Ada")

        var renamed = HostPatch(id: .manual("entry"), type: .textField)
        renamed.properties[.text] = .string("Grace")
        renderer.applyForTesting(changedTree(renamed))

        XCTAssertEqual(view.textField.stringValue, "Grace")
    }

    /// A field takes the members of the tiers it wears - its placeholder, and
    /// whether it is a password, read only, or enabled.
    @MainActor
    func testAFieldTakesTheMembersOfTheTiersItWears() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var entry = HostPatch(id: .manual("entry"), type: .textField)
        entry.properties[.placeholder] = .string("Name")
        entry.properties[.isPassword] = .bool(true)
        entry.properties[.isEnabled] = .bool(false)
        renderer.applyForTesting(tree(entry))

        let view = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("entry")) as? AppKitTextFieldView)

        XCTAssertEqual(view.textField.placeholderString, "Name")
        XCTAssertTrue(view.isSecure, "a password field swaps in the secure native field")
        XCTAssertFalse(view.textField.isEnabled)
    }

    /// A search field's words reach it the same way, through the same members.
    @MainActor
    func testASearchFieldTakesItsWordsAndPlaceholder() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var search = HostPatch(id: .manual("search"), type: .searchField)
        search.properties[.text] = .string("alpha")
        search.properties[.placeholder] = .string("Search")
        renderer.applyForTesting(tree(search))

        let view = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("search")) as? AppKitSearchFieldView)

        XCTAssertEqual(view.stringValue, "alpha")
        XCTAssertEqual(view.placeholderString, "Search")
    }
}
#endif

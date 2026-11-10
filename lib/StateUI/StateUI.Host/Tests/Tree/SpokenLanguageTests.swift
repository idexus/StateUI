// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The language an element's words are written in, read alike on every host: its own, else the nearest above it.
@MainActor
final class SpokenLanguageTests: XCTestCase {
    private func node(_ id: String, _ type: NodeType, language: String? = nil, children: [HostPatch] = []) -> HostPatch {
        var patch = HostPatch(id: .manual(id), type: type)
        if let language { patch.properties = [LanguageElementContract.language.token: LocaleTag(language).propValue] }
        patch.children = .arranged(children)
        return patch
    }

    /// An element holds the language of the nearest element saying one - a document under the interface its own -
    /// and none where nothing above says one; what follows an element's language stops at one saying its own.
    func testAnElementHoldsTheNearestLanguageAboveIt() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(node("window", .window, children: [
            node("interface", .vStack, language: "pl", children: [
                node("title", .text),
                node("document", .vStack, language: "en-GB", children: [node("letter", .text)]),
            ]),
            node("beside", .text),
        ]), complete: true)
        let root = try XCTUnwrap(runtime.tree.root)
        func element(_ id: String) throws -> MountedElement { try XCTUnwrap(root.first(id: .manual(id))) }

        XCTAssertEqual(try element("title").spokenLanguage, "pl")
        XCTAssertEqual(try element("letter").spokenLanguage, "en-GB")
        XCTAssertNil(try element("beside").spokenLanguage, "the platform's own")
        XCTAssertNil(try element("title").ownLanguage)
        XCTAssertEqual(try element("interface").followingLanguage.map(\.id), [.manual("interface"), .manual("title")])
    }

    /// Where the toolkit hands a view's language to the views in it, a view says its own; the first views under an
    /// element with no view saying one - a window - say that one, as does a view standing apart - a sheet's page, a
    /// popover; every other holds its view parent's.
    func testAViewSaysTheLanguageNoViewAboveItHolds() throws {
        let runtime = HostRuntime(
            clock: StillClock(), reducesMotion: { false }, makeNative: { NoView(presentsView: !$0.isViewless) },
            log: { _ in })
        runtime.tree.apply(node("window", .window, language: "pl", children: [
            node("page", .vStack, children: [
                node("title", .text),
                node("document", .vStack, language: "en", children: [node("letter", .text)]),
                node("sheet", .sheet, children: [node("sheetPage", .vStack)]),
            ]),
        ]), complete: true)
        let root = try XCTUnwrap(runtime.tree.root)
        func element(_ id: String) throws -> MountedElement { try XCTUnwrap(root.first(id: .manual(id))) }

        XCTAssertEqual(try element("page").languageOnItsView, "pl", "the window's, which has no view")
        XCTAssertNil(try element("title").languageOnItsView, "its view parent's")
        XCTAssertEqual(try element("document").languageOnItsView, "en", "its own")
        XCTAssertNil(try element("letter").languageOnItsView)
        XCTAssertEqual(try element("sheetPage").languageOnItsView, "pl", "a sheet's page stands apart")
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A link the user chose opens its address on every host alike, through the presenter's acts; a click of anything
/// else opens nothing.
@MainActor
final class LinkOpeningTests: XCTestCase {
    /// A presenter recording the addresses it opened.
    private final class Opening: HostPresenter {
        var opened: [String] = []
        func presentRendered(touchedChrome: Bool) {}
        func presentFrame(movedChrome: Bool) {}
        func perform(_ call: HostActCall) {}
        func open(link address: String) { opened.append(address) }
        func focus(_ element: MountedElement) {}
    }

    func testAChosenLinkOpensItsAddress() throws {
        let (runtime, presenter) = (HostRuntime.still(), Opening())
        runtime.presenter = presenter
        var root = HostPatch(id: .manual("root"), type: .vStack)
        var link = HostPatch(id: .manual("link"), type: .link)
        link.properties = [.destination: .string("https://www.swift.org"), .text: .string("Swift")]
        var button = HostPatch(id: .manual("button"), type: .button)
        button.properties = [.text: .string("Swift")]
        root.children = .arranged([link, button])
        runtime.tree.apply(root, complete: true)

        try XCTUnwrap(runtime.tree.root?.first(id: .manual("link"))).send(.clicked, [], in: runtime)
        try XCTUnwrap(runtime.tree.root?.first(id: .manual("button"))).send(.clicked, [], in: runtime)

        XCTAssertEqual(presenter.opened, ["https://www.swift.org"], "the link's address, and nothing for the button")
    }
}

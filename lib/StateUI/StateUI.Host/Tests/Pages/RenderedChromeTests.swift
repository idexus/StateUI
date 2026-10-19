// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// What a render changes of the windows' chrome: what it is made of, and nothing a page holds beside it.
@MainActor
final class RenderedChromeTests: XCTestCase {
    private let runtime = HostRuntime.still()

    override func setUp() async throws {
        runtime.tree.apply(Self.window(), complete: true)
        XCTAssertTrue(runtime.tree.takeChromeTouched(), "a first render makes the window")
    }

    /// A PAGE'S CONTENT CHANGED TOUCHES NO CHROME: its words, and a layout's children in a new order.
    func testAPagesContentChangedTouchesNoChrome() {
        var words = HostPatch(id: .manual("words"), type: .text)
        words.properties[.text] = .string("changed")
        XCTAssertFalse(touches(Self.content(.changed([words]))), "the page's words")

        XCTAssertFalse(touches(Self.content(.changed([Self.cards(["b", "a"])]))), "cards in a new order")
    }

    /// WHAT THE CHROME IS MADE OF TOUCHES IT: the page's title, and what an action holds.
    func testWhatTheChromeIsMadeOfTouchesIt() {
        var page = HostPatch(id: .manual("page"), type: .page)
        page.properties[.title] = .string("Drafts")
        XCTAssertTrue(touches(Self.window(page: page)), "the page's title")

        var words = HostPatch(id: .manual("action words"), type: .text)
        words.properties[.text] = .string("Send")
        var action = HostPatch(id: .manual("action"), type: .toolbarItem)
        action.children = .changed([words])
        var group = HostPatch(id: .manual("group"), type: .toolbarItemGroup)
        group.children = .changed([action])
        XCTAssertTrue(touches(Self.content(.changed([Self.holder(.changed([group]))]))), "an action's words")
    }

    /// A DECLARATION MADE OR LET GO TOUCHES THE CHROME, however deep in the page it stands.
    func testADeclarationMadeOrLetGoTouchesTheChrome() {
        var menu = HostPatch(id: .manual("menu"), type: .menuBar)
        menu.children = .arranged([])
        let words = HostPatch(id: .manual("x"), type: .text)
        XCTAssertTrue(touches(Self.content(.changed([Self.holder(.arranged([words, Self.group(), menu]))]))), "made")
        XCTAssertTrue(touches(Self.content(.changed([Self.holder(.arranged([words, Self.group()]))]))), "let go")
    }

    /// CHILDREN IN A NEW ORDER TOUCH THE CHROME WHERE ONE HOLDS A DECLARATION: the actions stand in the order the
    /// page's tree gives them.
    func testChildrenInANewOrderTouchTheChromeWhereOneHoldsADeclaration() {
        let holder = HostPatch(id: .manual("holder"), type: .vStack)
        let (words, cards) = (HostPatch(id: .manual("words"), type: .text), HostPatch(id: .manual("cards"), type: .zStack))

        XCTAssertTrue(touches(Self.content(.arranged([words, holder, cards]))))
    }

    /// A BRANCH TURNED DISABLED TOUCHES THE CHROME WHERE IT HOLDS A DECLARATION, whose actions it disables.
    func testABranchTurnedDisabledTouchesTheChromeWhereItHoldsADeclaration() {
        var cards = Self.cards(["a", "b"])
        cards.properties[.isEnabled] = .bool(false)
        XCTAssertFalse(touches(Self.content(.changed([cards]))), "a branch holding none")

        var holder = HostPatch(id: .manual("holder"), type: .vStack)
        holder.properties[.isEnabled] = .bool(false)
        XCTAssertTrue(touches(Self.content(.changed([holder]))), "the branch holding the page's actions")
    }

    // MARK: - A window over a page

    private func touches(_ patch: HostPatch) -> Bool {
        runtime.tree.apply(patch, complete: false)
        return runtime.tree.takeChromeTouched()
    }

    /// The application's one window showing the page: made where `page` is nil, else the way down to `page`.
    private static func window(page: HostPatch? = nil) -> HostPatch {
        let down = { (child: HostPatch) -> HostChildrenUpdate in page == nil ? .arranged([child]) : .changed([child]) }
        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = down(page ?? Self.page())
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = down(window)
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = down(scene)
        return application
    }

    /// The page: its words, a stack holding its actions, and cards.
    private static func page() -> HostPatch {
        var content = HostPatch(id: .manual("content"), type: .vStack)
        content.children = .arranged([
            holder(.arranged([HostPatch(id: .manual("x"), type: .text), group()])),
            HostPatch(id: .manual("words"), type: .text),
            cards(["a", "b"]),
        ])
        var page = HostPatch(id: .manual("page"), type: .page)
        page.children = .arranged([content])
        return page
    }

    /// The page's content as `children` change it.
    private static func content(_ children: HostChildrenUpdate) -> HostPatch {
        var content = HostPatch(id: .manual("content"), type: .vStack)
        content.children = children
        var page = HostPatch(id: .manual("page"), type: .page)
        page.children = .changed([content])
        return window(page: page)
    }

    private static func holder(_ children: HostChildrenUpdate) -> HostPatch {
        var holder = HostPatch(id: .manual("holder"), type: .vStack)
        holder.children = children
        return holder
    }

    private static func group() -> HostPatch {
        var action = HostPatch(id: .manual("action"), type: .toolbarItem)
        action.children = .arranged([HostPatch(id: .manual("action words"), type: .text)])
        var group = HostPatch(id: .manual("group"), type: .toolbarItemGroup)
        group.children = .arranged([action])
        return group
    }

    private static func cards(_ ids: [String]) -> HostPatch {
        var cards = HostPatch(id: .manual("cards"), type: .zStack)
        cards.children = .arranged(ids.map { HostPatch(id: .manual($0), type: .text) })
        return cards
    }
}

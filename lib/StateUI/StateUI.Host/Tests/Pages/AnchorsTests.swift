// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A composed view's anchor, the same on every host: no view of its own, what it holds standing in its place - in a
/// layout, as a window's arrangement, as a tab - and what it presents standing by the view it shows.
@MainActor
final class AnchorsTests: XCTestCase {
    private func node(
        _ id: String, _ type: NodeType, _ children: [HostPatch] = [], _ properties: [Prop: HostValue] = [:]
    ) -> HostPatch {
        var patch = HostPatch(id: .manual(id), type: type)
        patch.properties = properties
        patch.children = .arranged(children)
        return patch
    }

    private func mounted(_ root: HostPatch) throws -> (HostRuntime, MountedElement) {
        let runtime = HostRuntime.still()
        runtime.tree.apply(root, complete: true)
        return (runtime, try XCTUnwrap(runtime.tree.root))
    }

    /// A layout places what an anchor holds in the anchor's place, and nothing it presents.
    func testALayoutPlacesWhatAnAnchorHoldsInItsPlace() throws {
        let (_, window) = try mounted(node("window", .window, [node("page", .page, [
            node("stack", .vStack, [
                node("before", .text),
                node("anchor", .anchor, [node("shown", .text), node("sheet", .sheet)]),
                node("after", .text),
            ]),
        ])]))
        let stack = try XCTUnwrap(window.first(id: .manual("stack")))

        XCTAssertEqual(stack.arrangedChildren.map(\.id), [.manual("before"), .manual("shown"), .manual("after")])
        XCTAssertTrue(try XCTUnwrap(window.first(id: .manual("anchor"))).isViewless)
        XCTAssertEqual(try XCTUnwrap(window.first(id: .manual("shown"))).placingParent?.id, .manual("stack"))
    }

    /// An arrangement an anchor holds is the window's: the window shows it, and its chrome is the arrangement's.
    func testAnArrangementAnAnchorHoldsIsTheWindows() throws {
        let (runtime, window) = try mounted(node("window", .window, [
            node("anchor", .anchor, [
                node("split", .splitView, [node("sidebar", .page), node("detail", .page, [], [.title: .string("Inbox")])]),
            ]),
        ]))

        let shown = WindowPresentation().show(window, in: runtime.lifecycle)
        XCTAssertEqual(shown.arrangement?.shown?.id, .manual("split"))
        let chrome = WindowChrome(window: window, arrangement: shown.arrangement?.shown)
        XCTAssertEqual(chrome.title, "Inbox")
        XCTAssertEqual(chrome.splitView?.id, .manual("split"))
        XCTAssertTrue(chrome.showsSidebarToggle)
    }

    /// A tab an anchor holds is the tab: chosen, its stack's top page is the page shown.
    func testATabAnAnchorHoldsIsTheTab() throws {
        let (_, window) = try mounted(node("window", .window, [
            node("tabs", .tabView, [
                node("anchor", .anchor, [node("stack", .navigationStack, [node("root", .page)])]),
                node("other", .page),
            ]),
        ]))
        let tabs = try XCTUnwrap(window.first(id: .manual("tabs")))

        XCTAssertEqual(tabs.selectedTab?.id, .manual("stack"))
        XCTAssertEqual(tabs.visiblePage?.id, .manual("root"))
    }

    /// A popover shown on an anchor whose view is made anew - a branch flipped - is tried again after the render, to
    /// stand by the new view.
    func testAPopoverShownOnAnAnchorWhoseViewFlipsIsTriedAgain() throws {
        func tree(_ shown: String) -> HostPatch {
            node("window", .window, [node("page", .page, [
                node("anchor", .anchor, [node(shown, .button), node("popover", .popover, [], [.isPresented: .bool(true)])]),
            ])])
        }
        let (runtime, window) = try mounted(tree("narrow"))
        _ = runtime.tree.takeWaitingPopovers()

        runtime.tree.apply(tree("wide"), complete: true)

        let popover = try XCTUnwrap(window.first(id: .manual("popover")))
        XCTAssertTrue(popover.isMoving, "on its way to the new view")
        popover.reportDismissed(in: runtime)
        XCTAssertTrue(popover.asksToShow, "its old view's closing heard by nobody")

        XCTAssertEqual(runtime.tree.takeWaitingPopovers().map(\.id), [.manual("popover")])
        XCTAssertFalse(popover.isMoving, "taken again to stand by the new view")
        XCTAssertEqual(popover.presenter?.id, .manual("wide"))
    }

    /// A popover an anchor holds, asking to show as it is made, is tried again after the render: its view stood
    /// nowhere while the anchor's children were being made.
    func testAPopoverMadeWithItsAnchorIsTriedOnceItsViewStands() throws {
        let (runtime, window) = try mounted(node("window", .window, [node("page", .page, [
            node("anchor", .anchor, [node("button", .button), node("popover", .popover, [], [.isPresented: .bool(true)])]),
        ])]))

        XCTAssertEqual(runtime.tree.takeWaitingPopovers().map(\.id), [.manual("popover")])
        XCTAssertEqual(try XCTUnwrap(window.first(id: .manual("popover"))).presenter?.id, .manual("button"))
    }

    /// A popover written on a composed view stands by the view the view's anchor shows.
    func testAPopoverOnAnAnchorStandsByTheViewItShows() throws {
        let (_, window) = try mounted(node("window", .window, [node("page", .page, [
            node("anchor", .anchor, [node("button", .button), node("popover", .popover)]),
        ])]))

        XCTAssertEqual(try XCTUnwrap(window.first(id: .manual("popover"))).presenter?.id, .manual("button"))
    }
}

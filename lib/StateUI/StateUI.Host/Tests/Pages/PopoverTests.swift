// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A view's popover as every host shows it: while the tree asks, and once its window stands.
@MainActor
final class PopoverTests: XCTestCase {
    /// A popover asks to show while the tree says it is shown, and not before it says so.
    func testAPopoverAsksToShowAsTheTreeSays() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(anchors(["shown": true, "hidden": false]), complete: true)
        let root = try XCTUnwrap(runtime.tree.root)

        XCTAssertTrue(try popover(of: "shown", in: root).asksToShow)
        XCTAssertFalse(try popover(of: "hidden", in: root).asksToShow)
    }

    /// A popover its host could not show for want of its window is handed back once the render stands - in the
    /// order the popovers were made, and once.
    func testAPopoverWaitingForItsWindowIsHandedBackOnce() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(anchors(["first": true, "second": true]), complete: true)
        let root = try XCTUnwrap(runtime.tree.root)
        let first = try popover(of: "first", in: root)
        let second = try popover(of: "second", in: root)

        second.waitForItsWindow()
        first.waitForItsWindow()

        XCTAssertEqual(runtime.tree.takeWaitingPopovers().map(\.mount), [first.mount, second.mount])
        XCTAssertTrue(runtime.tree.takeWaitingPopovers().isEmpty, "taken once")
    }

    /// A popover that left the tree waits no more.
    func testAPopoverThatLeftWaitsNoMore() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(anchors(["first": true]), complete: true)
        try popover(of: "first", in: XCTUnwrap(runtime.tree.root)).waitForItsWindow()

        runtime.tree.apply(anchors([:]), complete: true)

        XCTAssertTrue(runtime.tree.takeWaitingPopovers().isEmpty)
    }

    /// A stack of buttons, each by its name with a popover the tree shows or not.
    private func anchors(_ shown: KeyValuePairs<String, Bool>) -> HostPatch {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged(shown.map { name, isShown in
            var popover = HostPatch(id: .manual(name + " popover"), type: .popover)
            popover.properties = [.isShown: .bool(isShown)]
            var button = HostPatch(id: .manual(name), type: .button)
            button.children = .arranged([popover])
            return button
        })
        return stack
    }

    /// The popover the button `name` declares.
    private func popover(of name: String, in root: MountedElement) throws -> MountedElement {
        try XCTUnwrap(XCTUnwrap(root.first(id: .manual(name))).popover)
    }
}

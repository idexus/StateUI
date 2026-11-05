// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class AimOwnershipTests: XCTestCase {
    private final class Lifetime {}

    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    func testAnAimDoesNotKeepTheRemovedListsContent() {
        let renders = Renders()
        let aim = Aim(ItemsView<Int>.self)
        weak var released: Lifetime?

        func list() -> Node {
            let lifetime = Lifetime()
            released = lifetime
            return ItemsView([1]) { _ in
                _ = lifetime
                return Text("One")
            }.aim(aim).node
        }

        _ = renders.render(stack([list()], id: "root"))
        XCTAssertNotNil(released)
        _ = renders.render(stack([], id: "root"))
        XCTAssertNil(released, "An Aim may remain declared after its list leaves; it must not retain that list's content.")

        // The audit leaves no retained graph behind even on the unfixed tree.
        aim.box.resolves = nil
        XCTAssertNil(released)
    }

    func testListContentCanCaptureItsAimWithoutFormingACycle() {
        let renders = Renders()
        weak var released: Aim<ItemsView<Int>>?

        func list() -> Node {
            let aim = Aim(ItemsView<Int>.self)
            released = aim
            return ItemsView([1]) { _ in
                Text(aim.description)
            }.aim(aim).node
        }

        _ = renders.render(stack([list()], id: "root"))
        XCTAssertNotNil(released)
        _ = renders.render(stack([], id: "root"))
        XCTAssertNil(released, "The item closure and the Aim must not keep one another after the list leaves.")

        released?.box.resolves = nil
        XCTAssertNil(released)
    }

    func testAListWithoutAnAimReleasesItsContent() {
        let renders = Renders()
        weak var released: Lifetime?

        func list() -> Node {
            let lifetime = Lifetime()
            released = lifetime
            return ItemsView([1]) { _ in
                _ = lifetime
                return Text("One")
            }.node
        }

        _ = renders.render(stack([list()], id: "root"))
        XCTAssertNotNil(released)
        _ = renders.render(stack([], id: "root"))
        XCTAssertNil(released)
    }
}

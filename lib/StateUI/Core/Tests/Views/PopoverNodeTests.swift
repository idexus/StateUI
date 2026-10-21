// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A view's popover as the core writes it: one slot holding what it shows, its state carried both ways.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class PopoverNodeTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// A view holds one popover - written again it stands in - its state carried in and out, what it shows its
    /// children.
    func testAPopoverIsOneSlotHoldingWhatItShows() throws {
        let shown = State(wrappedValue: false)
        let node = Text("Mine")
            .popover(isShown: shown.projectedValue) { Text("First") }
            .popover(isShown: shown.projectedValue) { Text("Inside") }
            .node

        XCTAssertEqual(node.children.map(\.type), [.popover], "one popover")
        let popover = try XCTUnwrap(node.children.last)
        XCTAssertEqual(popover.driven[.isShown]?.mode, .inOut, "the state carried both ways")
        XCTAssertEqual(popover.built.children.map(\.type), [.text])
    }

    /// A part of a state - which the host cannot carry - shows what it holds, and the user's dismissal writes it.
    func testTheDismissalWritesAStateTheHostCannotCarry() throws {
        var shown = true
        let renders = Renders()
        let patch = renders.render(VStack { Text("Mine") }
            .popover(isShown: Binding(get: { shown }, set: { shown = $0 })) { Text("Inside") }
            .node)
        let popover = try XCTUnwrap(patch.subtree.first { $0.type == .popover })

        XCTAssertEqual(popover.properties[.isShown], .bool(true))
        renders.fire(try XCTUnwrap(popover.events?[.isShownChanged]), with: [.bool(false)])
        XCTAssertFalse(shown, "the dismissal written into the state")
    }
}

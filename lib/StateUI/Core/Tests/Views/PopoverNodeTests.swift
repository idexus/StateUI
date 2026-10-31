// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A view's popover as the core writes it: one slot holding what it shows, its state carried both ways - the user's
// dismissal written back, the view leaving written too.

import XCTest

@_spi(Host) @testable import StateUI

/// A view standing while its state says so, presenting a popover.
private struct Leaving: View {
    let stands: Binding<Bool>
    let shown: Binding<Bool>

    var body: some View {
        VStack {
            if stands.wrappedValue {
                Button("Filters").popover(isPresented: shown) { Text("Inside") }
            }
        }
    }
}

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
            .popover(isPresented: shown.projectedValue) { Text("First") }
            .popover(isPresented: shown.projectedValue) { Text("Inside") }
            .node

        XCTAssertEqual(node.children.map(\.type), [.popover], "one popover")
        let popover = try XCTUnwrap(node.children.last)
        XCTAssertEqual(popover.driven[.isPresented]?.mode, .inOut, "the state carried both ways")
        XCTAssertEqual(popover.built.children.map(\.type), [.text])
    }

    /// A value shows what the content makes of it; the user's dismissal writes nil.
    func testTheDismissalWritesNilIntoItem() throws {
        let item = State<String?>(wrappedValue: "Inbox")
        let renders = Renders()
        let patch = renders.render(VStack { Text("Notes") }
            .popover(item: item.projectedValue) { name in Text(name) }
            .node)
        let popover = try XCTUnwrap(patch.subtree.first { $0.type == .popover })

        XCTAssertEqual(popover.properties[.isPresented], .bool(true))
        XCTAssertEqual(popover.children.first?.properties[.text], .string("Inbox"))
        renders.fire(try XCTUnwrap(popover.events?[.isPresentedChanged]), with: [.bool(false)])
        XCTAssertNil(item.wrappedValue, "the dismissal written into the state")
    }

    /// Another value shows another view in the popover, standing in the place of the first; no value shows none.
    func testAnotherItemIsAnotherView() throws {
        let note = State<String?>(wrappedValue: "Inbox")
        func popover() throws -> Node {
            try XCTUnwrap(Text("Notes").popover(item: note.projectedValue) { Text($0) }.node.children.first).built
        }
        let first = try popover()
        note.wrappedValue = "Sent"
        let second = try popover()
        note.wrappedValue = nil
        let none = try popover()

        XCTAssertNotEqual(first.children.first?.identity, second.children.first?.identity)
        XCTAssertEqual(none.props[.isPresented], .bool(false))
        XCTAssertTrue(none.children.isEmpty, "nothing to show")
    }

    /// The view presenting a popover leaves the tree: its popover closes, and its state is written false.
    func testAViewLeavingClosesItsPopover() throws {
        let (stands, shown) = (State(wrappedValue: true), State(wrappedValue: true))
        let renders = Renders()
        _ = renders.settled(Leaving(stands: stands.projectedValue, shown: shown.projectedValue).node)

        stands.wrappedValue = false
        _ = renders.settled(
            Leaving(stands: stands.projectedValue, shown: shown.projectedValue).node,
            changed: Renderer.shared.pendingChanges)
        XCTAssertFalse(shown.wrappedValue, "the state says the popover is closed")
    }
}

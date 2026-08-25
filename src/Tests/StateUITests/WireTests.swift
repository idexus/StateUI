// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The wire format itself, written down.
//
// These produce the exact messages the C# side is given, and keep them in
// `src/Tests/fixtures/`. The renderer tests next door read the SAME files,
// so the two halves cannot drift apart quietly: change what Swift sends and this
// test fails; update the fixture and the C# test starts exercising the new
// shape.
//
// Run with STATEUI_UPDATE_FIXTURES=1 to write them instead of checking them,
// which is the whole of "the design assumption changed, update the test".
//
// This one covers the SHAPE of a message - what a first render says, and what
// the renders after it leave out. What each control puts in one is next door,
// in ControlTests.

import Foundation
import StateUIWireProbe
import XCTest
@testable import StateUI

final class WireTests: XCTestCase {
    /// One `WireNames` per SEQUENCE, because the messages of a session
    /// announce each name once - the later sidecars resolve through what the
    /// earlier messages taught.
    private func check(_ bytes: [UInt8], names: WireNames, against name: String) throws {
        try Fixtures.check(bytes, sidecar: WireProbe.dumpMessage(bytes, names: names), against: name)
    }

    /// The counter page of the sample, in miniature: enough to carry a title, a
    /// value that changes, a button with a handler, and a keyed list.
    ///
    /// Under the APPLICATION, which is what a message is rooted in - one window
    /// here, as most applications have. See `Renderer.root`.
    private func page(count: Int, items: [String], sized: Bool = true) -> Node {
        Node(type: "Application", children: [window(count: count, items: items, sized: sized)])
    }

    /// The counting label, which says how big it is and how it is spaced
    /// until it stops - the properties in this tree that GO AWAY, so that a
    /// message clearing some is among the fixtures. TWO of them, because a
    /// cleared list of one cannot show it is written in name order.
    private func counter(count: Int, sized: Bool) -> Node {
        var props: [Prop: PropValue] = ["text": .string("Count: \(count)")]

        if sized {
            props["fontSize"] = .number(20)
            props["characterSpacing"] = .number(1.5)
        }

        return Node(type: "Label", props: props)
    }

    /// The window of that page, with the tree under it.
    private func window(count: Int, items: [String], sized: Bool = true) -> Node {
        Node(type: "Window", props: ["title": .string("StateUI")], children: [
            Node(type: "ContentPage", props: ["title": .string("Counter")], children: [
                Node(type: "VerticalStackLayout", props: ["spacing": .number(20)], children: [
                    counter(count: count, sized: sized),
                    Node(type: "Button",
                         props: ["text": .string("Increment")],
                         events: ["clicked": {}]),
                    Node(type: "VerticalStackLayout",
                         children: items.map { label($0, id: $0) }),
                ]),
            ]),
        ])
    }

    func testTheWireFormat() throws {
        let differ = Differ()
        var rendered: RenderedNode?

        // ONE dictionary for the whole sequence, the way a session keeps one:
        // the first render announces every name it uses, and the patches after
        // it announce nothing - which the fixtures therefore demonstrate.
        let dictionary = WireDictionary()
        let names = WireNames()

        func render(_ tree: Node, generation: Int32) -> [UInt8] {
            let result = differ.reconcile(rendered, with: tree)
            rendered = result.node
            return Wire.encode(result.patch, generation: generation, dictionary: dictionary)
        }

        // 1. Everything, because the host has nothing.
        try check(render(page(count: 0, items: ["a", "b"]), generation: 1),
                  names: names, against: "first-render")

        // 2. One number changed: one label, one property.
        try check(render(page(count: 1, items: ["a", "b"]), generation: 2),
                  names: names, against: "counter-changed")

        // 3. A row inserted at the top: one new row, two that only moved.
        try check(render(page(count: 1, items: ["z", "a", "b"]), generation: 3),
                  names: names, against: "list-inserted")

        // 4. And one removed from the middle.
        try check(render(page(count: 1, items: ["z", "b"]), generation: 4),
                  names: names, against: "list-removed")

        // 5. The host lost track: everything again, said so in the envelope -
        //    and against the SAME identities, so nothing on screen is replaced.
        //    The dictionary does NOT start over: a resync renegotiates the
        //    tree, never the session's names.
        func renderFromScratch(_ tree: Node, generation: Int32) -> [UInt8] {
            let result = differ.reconcile(rendered, with: tree, describeAll: true)
            rendered = result.node
            return Wire.encode(
                result.patch, generation: generation, complete: true, dictionary: dictionary)
        }

        try check(renderFromScratch(page(count: 1, items: ["z", "b"]), generation: 5),
                  names: names, against: "resync")

        // 6. The label stops saying how big it is. The element is NOT replaced
        //    - the property that went away is named, and the host clears it,
        //    so everything below keeps its controls, its handlers and its
        //    state.
        try check(render(page(count: 1, items: ["z", "b"], sized: false), generation: 6),
                  names: names, against: "property-cleared")
    }

    /// The window's lifetime on the wire: six handlers on the WINDOW node, the
    /// ids the host's Window events report with. The C# WindowTests apply
    /// this very file to a real StateUIWindow and read the map back off it.
    func testTheWindowsLifetimeIsTheWindowsEvents() throws {
        let differ = Differ()

        let window = Node(
            type: "Window",
            props: ["title": .string("StateUI")],
            children: [
                Node(type: "ContentPage", props: ["title": .string("Home")], children: [
                    Node(type: "Label", props: ["text": .string("one")]),
                ]),
            ],
            events: [
                "created": {}, "activated": {}, "deactivated": {},
                "stopped": {}, "resumed": {}, "destroying": {},
            ])

        try check(
            Wire.encode(
                differ.reconcile(
                    nil, with: Node(type: "Application", children: [window])).patch,
                generation: 1,
                dictionary: WireDictionary()),
            names: WireNames(),
            against: "window-lifecycle")
    }
}

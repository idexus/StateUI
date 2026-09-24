// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The shape of a patch, written down: what a first render says, and what the
// renders after it leave out. The patches are kept in
// `lib/StateUI/Tests/Fixtures/`, where a host's tests read the same files, so
// the two halves cannot drift apart quietly: change what Swift sends and this
// test fails; update the fixture and a host test that reads it exercises the
// new shape.
//
// Run with STATEUI_UPDATE_FIXTURES=1 to write them instead of checking them,
// which is the whole of "the design assumption changed, update the test".
//
// What each control puts in one is next door, in ControlTests.

import XCTest
@_spi(Host) @testable import StateUI

final class PatchShapeTests: XCTestCase {
    /// The counter page of the sample, in miniature: enough to carry a title, a
    /// value that changes, a button with a handler, and a keyed list.
    ///
    /// Under the application and its scene, which is where every render is
    /// rooted - the scene's main window, as most applications have one. See
    /// `Renderer.root`.
    private func page(count: Int, items: [String], sized: Bool = true) -> Node {
        var main = window(count: count, items: items, sized: sized)
        main.id = SceneElement.mainKey

        var scene = Node(type: "Scene", children: [main])
        scene.id = "1"

        return Node(type: "Application", children: [scene])
    }

    /// The counting label, which says how big it is and how it is spaced
    /// until it stops - the properties in this tree that GO AWAY, so that a
    /// patch clearing some is among the fixtures. TWO of them, because a
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
            Node(type: "Page", props: ["title": .string("Counter")], children: [
                Node(type: "VStack", props: ["spacing": .number(20)], children: [
                    counter(count: count, sized: sized),
                    Node(type: "Button",
                         props: ["text": .string("Increment")],
                         events: ["clicked": {}]),
                    Node(type: "VStack",
                         children: items.map { label($0, id: $0) }),
                ]),
            ]),
        ])
    }

    func testTheShapeOfEachRender() throws {
        let differ = Differ()
        var rendered: RenderedNode?

        // One session for the whole sequence, the way one host hears it.
        let session = FixtureSession()

        func render(_ tree: Node, complete: Bool = false, against name: String) throws {
            let result = differ.reconcile(rendered, with: tree, describeAll: complete)
            rendered = result.node
            try Fixtures.check(result.patch, complete: complete, in: session, against: name)
        }

        // 1. Everything, because the host has nothing.
        try render(page(count: 0, items: ["a", "b"]), against: "first-render")

        // 2. One number changed: one label, one property.
        try render(page(count: 1, items: ["a", "b"]), against: "counter-changed")

        // 3. A row inserted at the top: one new row, two that only moved.
        try render(page(count: 1, items: ["z", "a", "b"]), against: "list-inserted")

        // 4. And one removed from the middle.
        try render(page(count: 1, items: ["z", "b"]), against: "list-removed")

        // 5. The host lost track: everything again, said so - and against the
        //    SAME identities, so nothing on screen is replaced.
        try render(page(count: 1, items: ["z", "b"]), complete: true, against: "resync")

        // 6. The label stops saying how big it is. The element is NOT replaced
        //    - the property that went away is named, and the host clears it,
        //    so everything below keeps its controls, its handlers and its
        //    state.
        try render(page(count: 1, items: ["z", "b"], sized: false), against: "property-cleared")
    }

    /// The window's lifetime: six handlers on the WINDOW element, the ids the
    /// host's window reports each moment of its life with.
    func testTheWindowsLifetimeIsTheWindowsEvents() throws {
        let window = Node(
            type: "Window",
            props: ["title": .string("StateUI")],
            children: [
                Node(type: "Page", props: ["title": .string("Home")], children: [
                    Node(type: "Label", props: ["text": .string("one")]),
                ]),
            ],
            events: [
                "created": {}, "activated": {}, "deactivated": {},
                "stopped": {}, "resumed": {}, "destroying": {},
            ])

        // Under the application and its scene, which is where every window
        // stands - the scene's main window, known by what the tree calls one.
        var main = window
        main.id = SceneElement.mainKey

        var scene = Node(type: "Scene", children: [main])
        scene.id = "1"

        try Fixtures.check(
            Differ().reconcile(nil, with: Node(type: "Application", children: [scene])).patch,
            against: "window-lifecycle")
    }
}

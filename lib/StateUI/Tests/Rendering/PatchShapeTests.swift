// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The shape of a patch: what a first render says, and what the renders after
// it leave out - each render asserted by the rule it keeps. What each control
// puts in one is next door, in ControlTests.

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
    /// patch clearing some is among the renders. TWO of them, because a
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

        func render(_ tree: Node, complete: Bool = false) -> HostPatch {
            let result = differ.reconcile(rendered, with: tree, describeAll: complete)
            rendered = result.node
            return result.patch
        }

        // The page's counter, button and list, below the application: its
        // scene, its main window, the page and the stack.
        let stack: [ElementId] = [.manual("1"), .manual(SceneElement.mainKey), .auto(2), .auto(3)]
        let counter = stack + [.auto(4)]
        let button = stack + [.auto(5)]
        let list = stack + [.auto(6)]

        // 1. Everything, because the host has nothing: every element with all
        //    it says, every container's arrangement in full.
        let first = render(page(count: 0, items: ["a", "b"]))
        XCTAssertEqual(first.at(counter)?.props, [
            "text": .string("Count: 0"), "fontSize": .number(20), "characterSpacing": .number(1.5),
        ])
        XCTAssertEqual(first.at(button)?.eventNames, ["clicked"])
        XCTAssertEqual(first.at(list)?.arrangement, [.manual("a"), .manual("b")])
        XCTAssertTrue(
            first.subtree.filter { !$0.children.isEmpty }.allSatisfy(\.arranged),
            "a first render arranges every container in full")

        // 2. One number changed: one label, one property - and nothing else in
        //    the message says anything.
        let changed = render(page(count: 1, items: ["a", "b"]))
        XCTAssertEqual(changed.at(counter)?.props, ["text": .string("Count: 1")])
        XCTAssertEqual(Self.speaking(changed), [.auto(4)])
        XCTAssertFalse(changed.subtree.contains(where: \.arranged), "no arrangement moved")

        // 3. A row inserted at the top: one new row, two that only moved.
        let inserted = render(page(count: 1, items: ["z", "a", "b"]))
        XCTAssertEqual(inserted.at(list)?.arrangement, [.manual("z"), .manual("a"), .manual("b")])
        XCTAssertEqual(Self.speaking(inserted), [.manual("z")], "the rows that only moved say nothing")

        // 4. And one removed from the middle: the arrangement says so, alone.
        let removed = render(page(count: 1, items: ["z", "b"]))
        XCTAssertEqual(removed.at(list)?.arrangement, [.manual("z"), .manual("b")])
        XCTAssertEqual(Self.speaking(removed), [])

        // 5. The host lost track: everything again, said so - and against the
        //    SAME identities, so nothing on screen is replaced.
        let resync = render(page(count: 1, items: ["z", "b"]), complete: true)
        XCTAssertEqual(resync.at(counter)?.props, [
            "text": .string("Count: 1"), "fontSize": .number(20), "characterSpacing": .number(1.5),
        ])
        XCTAssertEqual(resync.at(list)?.arrangement, [.manual("z"), .manual("b")])
        let kept = first.subtree.map(\.id).filter { $0 != .manual("a") } + [.manual("z")]
        XCTAssertEqual(
            Set(resync.subtree.map(\.id)), Set(kept),
            "the same identities: the first render's, and the row inserted since")
        XCTAssertFalse(resync.subtree.contains(where: \.replace), "nothing on screen is replaced")

        // 6. The label stops saying how big it is. The element is NOT replaced
        //    - the properties that went away are named, in name order, and
        //    the host clears them, so everything below keeps its controls,
        //    its handlers and its state.
        let cleared = render(page(count: 1, items: ["z", "b"], sized: false))
        let label = try XCTUnwrap(cleared.at(counter))
        XCTAssertEqual(label.cleared, ["characterSpacing", "fontSize"])
        XCTAssertEqual(label.props, [:])
        XCTAssertFalse(label.replace)
        XCTAssertEqual(Self.speaking(cleared), [.auto(4)])
    }

    /// The window's lifetime: six handlers on the WINDOW element, one id each,
    /// the ids the host's window reports each moment of its life with.
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

        let patch = Differ().reconcile(nil, with: Node(type: "Application", children: [scene])).patch
        let handlers = try XCTUnwrap(patch.at(.manual("1"), .manual(SceneElement.mainKey))?.events?.handlers)

        XCTAssertEqual(
            handlers.keys.map(\.name).sorted(),
            ["activated", "created", "deactivated", "destroying", "resumed", "stopped"])
        XCTAssertEqual(Set(handlers.values).count, 6, "one handler id for each moment")
    }

    /// The elements a patch has anything to say about - a property, a cleared
    /// property, a handler, a replacement - by identity; the rest carry only
    /// the path down.
    private static func speaking(_ patch: HostPatch) -> [ElementId] {
        patch.subtree.filter { !$0.props.isEmpty || !$0.cleared.isEmpty || $0.events != nil || $0.replace }
            .map(\.id)
    }
}

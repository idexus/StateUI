// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What a window asks its host to show, as it changes.
@MainActor
final class WindowPresentationTests: XCTestCase {
    /// A window shows the first arrangement of pages among its children and its overlay, says each only when it
    /// changes, and is told it was made once.
    func testAWindowSaysWhatItShowsOnlyAsItChanges() throws {
        let runtime = HostRuntime.still()
        func window(_ children: [HostPatch]) -> HostPatch {
            var window = HostPatch(id: .manual("window"), type: .window)
            window.events = .replace([.created: 5])
            window.children = .arranged(children)
            return window
        }
        runtime.tree.apply(window([HostPatch(id: .manual("page"), type: .page)]), complete: true)
        var told: [Int32] = []
        runtime.tree.tellPhase = { told.append($0) }
        let presentation = WindowPresentation()

        let first = presentation.show(try XCTUnwrap(runtime.tree.root), in: runtime.lifecycle)
        XCTAssertEqual(first.arrangement?.shown?.id, .manual("page"))
        XCTAssertNil(first.arrangement?.previous)
        XCTAssertEqual(told, [5])
        XCTAssertNil(first.overlays, "no overlay, before or now: nothing to say")

        let again = presentation.show(try XCTUnwrap(runtime.tree.root), in: runtime.lifecycle)
        XCTAssertNil(again.arrangement)
        XCTAssertNil(again.overlays, "nothing new to lay over")
        XCTAssertEqual(told, [5], "told it was made once")
    }

    private func node(_ id: String, _ type: NodeType, _ children: [HostPatch] = []) -> HostPatch {
        var patch = HostPatch(id: .manual(id), type: type)
        patch.children = .arranged(children)
        return patch
    }

    /// An overlay `id`, holding one layer.
    private func overlay(_ id: String) -> HostPatch {
        node(id, .overlay, [node("\(id).layer", .zStack)])
    }

    /// A modal stack standing as a window's page: its root is what the window shows, its other pages the sheets over
    /// it, the last on top.
    func testAModalStackShowsItsRootUnderItsSheets() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(node("window", .window, [
            node("modal", .modalStack, [
                node("stack", .navigationStack, [node("home", .page)]), node("first", .page), node("second", .page),
            ]),
        ]), complete: true)

        let changes = WindowPresentation().show(try XCTUnwrap(runtime.tree.root), in: runtime.lifecycle)
        XCTAssertEqual(changes.arrangement?.shown?.id, .manual("stack"))
        XCTAssertEqual(changes.sheets?.map(\.id), [.manual("first"), .manual("second")])
    }

    /// The overlays a window lays: those its shown path declares, the outer under the inner, then each sheet's, then
    /// the library's own over every other; a page pushed over another takes that page's away.
    func testTheOverlaysOfAWindowStandInThePathsOrder() throws {
        let runtime = HostRuntime.still()
        func tree(pushed: Bool) -> HostPatch {
            node("window", .window, [
                node("modal", .modalStack, [
                    node("stack", .navigationStack, [
                        node("home", .page, [node("content", .vStack, [node("words", .text), overlay("home's")])]),
                    ] + (pushed ? [node("detail", .page)] : []) + [overlay("stack's")]),
                    node("sheet", .page, [overlay("sheet's")]),
                ]),
                overlay("inspector"),
            ])
        }
        runtime.tree.apply(tree(pushed: false), complete: true)
        let presentation = WindowPresentation()
        let root = try XCTUnwrap(runtime.tree.root)

        let first = presentation.show(root, in: runtime.lifecycle)
        XCTAssertEqual(first.overlays?.map(\.id), [
            .manual("stack's"), .manual("home's"), .manual("sheet's"), .manual("inspector"),
        ])

        runtime.tree.apply(tree(pushed: true), complete: true)
        let pushed = presentation.show(root, in: runtime.lifecycle)
        XCTAssertEqual(pushed.overlays?.map(\.id), [.manual("stack's"), .manual("sheet's"), .manual("inspector")],
                       "the home page's went with it")
    }

    /// A window's place and size are four requests, each said alone where the tree changed it; one it keeps, or
    /// takes away, moves nothing.
    func testAWindowsFrameIsFourRequestsEachAlone() throws {
        let runtime = HostRuntime.still()
        var window = HostPatch(id: .manual("window"), type: .window)
        window.properties = [.x: .number(40), .width: .number(640)]
        runtime.tree.apply(window, complete: true)
        let presentation = WindowPresentation()
        let root = try XCTUnwrap(runtime.tree.root)
        func change(_ properties: [Prop: HostValue], clearing cleared: [Prop] = []) -> WindowFrame? {
            var patch = HostPatch(id: .manual("window"), type: .window)
            patch.properties = properties
            patch.clearedProperties = cleared
            runtime.tree.apply(patch, complete: false)
            return presentation.show(root, in: runtime.lifecycle).frame
        }

        XCTAssertEqual(presentation.show(root, in: runtime.lifecycle).frame, WindowFrame(x: 40, width: 640))
        XCTAssertEqual(
            change([.x: .number(40), .width: .number(800), .height: .number(480)]), WindowFrame(width: 800, height: 480))
        XCTAssertNil(change([:]), "nothing changed: the window stays where the user put it")
        XCTAssertNil(change([:], clearing: [.x]), "a request taken away moves nothing")
        XCTAssertEqual(change([.x: .number(40)]), WindowFrame(x: 40), "asked again, it moves the window again")
        XCTAssertNil(change([.width: .number(-1)]), "a size below nothing asks for none")
    }

    /// A window's bounds are said the first time and where they change; a greatest below the least is the least.
    func testAWindowsGreatestSizeNeverStandsBelowItsLeast() throws {
        let runtime = HostRuntime.still()
        var window = HostPatch(id: .manual("window"), type: .window)
        window.properties = [.minimumWidth: .number(400), .maximumWidth: .number(300), .maximumHeight: .number(900)]
        runtime.tree.apply(window, complete: true)
        let presentation = WindowPresentation()
        let root = try XCTUnwrap(runtime.tree.root)

        let bounds = try XCTUnwrap(presentation.show(root, in: runtime.lifecycle).bounds)
        XCTAssertEqual(bounds.minimumWidth, 400)
        XCTAssertEqual(bounds.maximumWidth, 400, "the least wins")
        XCTAssertNil(bounds.minimumHeight, "unsaid: the toolkit's own")
        XCTAssertEqual(bounds.maximumHeight, 900)
        XCTAssertNil(presentation.show(root, in: runtime.lifecycle).bounds, "said once until they change")
    }
}

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
        XCTAssertTrue(first.overlay == nil, "no overlay, before or now: nothing to say")

        let again = presentation.show(try XCTUnwrap(runtime.tree.root), in: runtime.lifecycle)
        XCTAssertNil(again.arrangement)
        XCTAssertTrue(again.overlay == nil, "nothing new to lay over")
        XCTAssertEqual(told, [5], "told it was made once")
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

    /// A window of a kind of its own belongs to its scene's main window, and a main window to none - said the first
    /// time, whatever it is, and then only where it changes.
    func testAWindowOfItsOwnBelongsToItsScenesMainWindow() throws {
        let runtime = HostRuntime.still()
        var tool = HostPatch(id: .manual("tool"), type: .window)
        tool.properties = [.windowType: .name("tool")]
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([tool, HostPatch(id: .manual("main"), type: .window)])
        runtime.tree.apply(scene, complete: true)
        let main = try XCTUnwrap(runtime.tree.root?.first(id: .manual("main")))
        let owned = try XCTUnwrap(runtime.tree.root?.first(id: .manual("tool")))
        let (mainPresentation, toolPresentation) = (WindowPresentation(), WindowPresentation())

        let mainOwner = try XCTUnwrap(mainPresentation.show(main, in: runtime.lifecycle).owner, "said the first time")
        XCTAssertNil(mainOwner, "a main window belongs to none")
        XCTAssertTrue(toolPresentation.show(owned, in: runtime.lifecycle).owner??.id == .manual("main"),
                      "wherever it stands among the scene's windows")
        XCTAssertNil(toolPresentation.show(owned, in: runtime.lifecycle).owner, "said once until it changes")
    }
}

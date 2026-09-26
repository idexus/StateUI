// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The windows a tree holds, as a host keeps them.
@MainActor
final class WindowRosterTests: XCTestCase {
    /// Each window element has a controller, in the tree's order: one the tree keeps keeps its controller, one it
    /// no longer holds is closed, and the first window's coming is said once.
    func testAWindowKeepsItsControllerWhileTheTreeHoldsIt() throws {
        final class Controller {
            let name: String
            init(_ name: String) { self.name = name }
        }
        let runtime = HostRuntime.still()
        func scene(_ windows: [String]) {
            var scene = HostPatch(id: .manual("scene"), type: .scene)
            scene.children = .arranged(windows.map { HostPatch(id: .manual($0), type: .window) })
            runtime.tree.apply(scene, complete: false)
        }
        let roster = WindowRoster<Controller>()
        var made: [String] = []
        var closed: [String] = []
        func update() -> Bool {
            roster.update(
                root: runtime.tree.root,
                make: { element in
                    guard case .manual(let name) = element.id else { return Controller("?") }
                    made.append(name)
                    return Controller(name)
                },
                close: { closed.append($0.name) })
        }

        scene(["main", "note"])
        XCTAssertTrue(update(), "the first window came")
        XCTAssertEqual(roster.controllers.map(\.name), ["main", "note"])
        let note = try XCTUnwrap(runtime.tree.root?.first(id: .manual("note")))
        XCTAssertEqual(roster.controller(of: note)?.name, "note")

        scene(["main", "note"])
        XCTAssertFalse(update())
        XCTAssertEqual(made, ["main", "note"], "the windows kept keep their controllers")

        scene(["main"])
        _ = update()
        XCTAssertEqual(closed, ["note"])
        XCTAssertEqual(roster.controllers.map(\.name), ["main"])

        scene(["main", "note", "fonts"])
        _ = update()
        closed = []
        scene([])
        _ = update()
        XCTAssertEqual(closed, ["fonts", "note", "main"], "the last first: a window before the one it belongs to")
    }

    /// A window's traits are said the first time and where they change; what it leaves unsaid of its buttons is
    /// the toolkit's.
    func testAWindowsTraitsAreSaidWhereTheyChange() throws {
        let runtime = HostRuntime.still()
        var window = HostPatch(id: .manual("window"), type: .window)
        window.properties = [.isMinimizable: .bool(false), .floatsOnTop: .bool(true)]
        runtime.tree.apply(window, complete: true)
        let presentation = WindowPresentation()
        let root = try XCTUnwrap(runtime.tree.root)

        let traits = try XCTUnwrap(presentation.show(root, in: runtime.lifecycle).traits)
        XCTAssertNil(traits.isMaximizable, "unsaid: the toolkit's own")
        XCTAssertEqual(traits.isMinimizable, false)
        XCTAssertTrue(traits.floatsOnTop)
        XCTAssertNil(presentation.show(root, in: runtime.lifecycle).traits, "said once until they change")
    }
}

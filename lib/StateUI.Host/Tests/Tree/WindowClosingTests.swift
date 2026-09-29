// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What the user closing a window tells, the same on every host.
@MainActor
final class WindowClosingTests: XCTestCase {
    /// The scene's main window hears it is going, then its scene that it is going too.
    func testClosingTheMainWindowEndsItsScene() throws {
        let runtime = scene()
        let told = HostRuntime.toldOnClosing(try XCTUnwrap(runtime.tree.root?.first(id: .manual("main"))))

        XCTAssertEqual(told.map { $0.handler }, [3, 1])
        XCTAssertEqual(told.map { $0.payload }, [[], []])
    }

    /// A window of its own hears it is going, then its scene hears which one closed, by the window's key.
    func testClosingAWindowOfItsOwnTellsItsSceneTheKey() throws {
        let runtime = scene()
        let told = HostRuntime.toldOnClosing(try XCTUnwrap(runtime.tree.root?.first(id: .manual("note-7"))))

        XCTAssertEqual(told.map { $0.handler }, [4, 2])
        XCTAssertEqual(told.map { $0.payload }, [[], [.string("note-7")]])
    }

    /// A scene holding its main window and a note's window of its own.
    private func scene() -> HostRuntime {
        let runtime = HostRuntime.still()
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.events = .replace([.destroying: 1, .windowClosed: 2])
        var main = HostPatch(id: .manual("main"), type: .window)
        main.events = .replace([.destroying: 3])
        var note = HostPatch(id: .manual("note-7"), type: .window)
        note.properties = [.windowType: .name("notes.note")]
        note.events = .replace([.destroying: 4])
        scene.children = .arranged([main, note])
        runtime.tree.apply(scene, complete: true)
        return runtime
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What the user closing a window tells, the same on every host.
@MainActor
final class WindowClosingTests: XCTestCase {
    /// A window hears it is going, then its scene which one closed, by the window's key - whichever window of the
    /// scene it is: the scene ends with its last.
    func testClosingAWindowTellsItThenItsSceneTheKey() throws {
        let runtime = scene()

        for (key, handler) in [("window 1", Int32(3)), ("note 2", Int32(4))] {
            let told = HostRuntime.toldOnClosing(try XCTUnwrap(runtime.tree.root?.first(id: .manual(key))))

            XCTAssertEqual(told.map { $0.handler }, [handler, 2])
            XCTAssertEqual(told.map { $0.payload }, [[], [.string(key)]])
        }
    }

    /// A scene holding a window of the group with no name and a note's window.
    private func scene() -> HostRuntime {
        let runtime = HostRuntime.still()
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.events = .replace([.windowClosed: 2])
        var window = HostPatch(id: .manual("window 1"), type: .window)
        window.events = .replace([.destroying: 3])
        var note = HostPatch(id: .manual("note 2"), type: .window)
        note.properties = [.windowType: .name("notes.note")]
        note.events = .replace([.destroying: 4])
        scene.children = .arranged([window, note])
        runtime.tree.apply(scene, complete: true)
        return runtime
    }
}

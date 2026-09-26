// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Where the application, its scenes and its windows stand as a toolkit tells what each window does, and what each
/// hears of it.
@MainActor
final class ApplicationLifecycleTests: XCTestCase {
    /// A window's state is the application's phase - activated in use, deactivated behind another, minimized seen
    /// nowhere - told to the scene, then to the window; a window shown again hears first, once, that it resumed; a
    /// state told again tells nothing.
    func testAWindowsStateIsTheApplicationsPhase() throws {
        let (runtime, lifecycle) = Self.application([("1", [Self.window("main")])])
        let main = try Self.window("main", in: "1", of: runtime)

        lifecycle.report(main, minimized: false, activated: true)
        var moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertEqual(moves.phase, .active)
        XCTAssertEqual(Self.names(moves.told), ["1 activated", "1/main activated"])
        XCTAssertTrue(lifecycle.settle(windows: runtime.tree.root!.windows).told.isEmpty, "told again, nothing")

        lifecycle.report(main, minimized: false, activated: false)
        moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertEqual(moves.phase, .inactive)
        XCTAssertEqual(Self.names(moves.told), ["1 deactivated", "1/main deactivated"])

        lifecycle.report(main, minimized: true, activated: true)
        moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertEqual(moves.phase, .background, "minimized, whatever its activation")
        XCTAssertEqual(Self.names(moves.told), ["1 stopped", "1/main stopped"])

        lifecycle.report(main, minimized: false, activated: false)
        moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertEqual(moves.phase, .inactive)
        XCTAssertEqual(Self.names(moves.told), ["1/main resumed", "1 deactivated", "1/main deactivated"])

        lifecycle.report(main, minimized: false, activated: true)
        XCTAssertEqual(Self.names(lifecycle.settle(windows: runtime.tree.root!.windows).told),
                       ["1 activated", "1/main activated"], "resumed once")
    }

    /// One window deactivated as another of the application is activated is one move: the application stays in use,
    /// the scene hears nothing, and what leaves hears it before what is activated.
    func testMovingBetweenTheApplicationsWindowsKeepsItInUse() throws {
        let (runtime, lifecycle) = Self.application([("1", [Self.window("main"), Self.window("tool", kind: "tool")])])
        let main = try Self.window("main", in: "1", of: runtime)
        let tool = try Self.window("tool", in: "1", of: runtime)
        lifecycle.report(main, minimized: false, activated: true)
        _ = lifecycle.settle(windows: runtime.tree.root!.windows)

        lifecycle.report(main, minimized: false, activated: false)
        lifecycle.report(tool, minimized: false, activated: true)
        let moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertNil(moves.phase, "still in use")
        XCTAssertEqual(Self.names(moves.told), ["1/main deactivated", "1/tool activated"])
    }

    /// The scene in front is the one whose window was activated last: the application going behind another moves it
    /// nowhere, another scene's window activated moves it there - the scene left hears it first.
    func testOnlyAnotherScenesWindowMovesTheSceneInFront() throws {
        let (runtime, lifecycle) = Self.application([("1", [Self.window("main")]), ("2", [Self.window("main")])])
        let first = try Self.window("main", in: "1", of: runtime)
        let second = try Self.window("main", in: "2", of: runtime)
        let scene1 = try XCTUnwrap(first.enclosing(type: .scene))

        lifecycle.report(first, minimized: false, activated: true)
        _ = lifecycle.settle(windows: runtime.tree.root!.windows)
        lifecycle.report(first, minimized: false, activated: false)
        XCTAssertEqual(lifecycle.settle(windows: runtime.tree.root!.windows).phase, .inactive)
        XCTAssertTrue(lifecycle.front === scene1, "the application behind another moves no scene")

        lifecycle.report(second, minimized: false, activated: true)
        let moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertTrue(lifecycle.front === second.enclosing(type: .scene))
        XCTAssertTrue(moves.standing, "the scene in front moved")
        XCTAssertEqual(Self.names(moves.told), ["2 activated", "2/main activated"])
    }

    /// A window that hides while another scene is in front stands hidden, and stopped, while one is; it stands again
    /// as its scene comes to the front. Before any scene came to the front, none hides.
    func testAWindowHidesWhileAnotherSceneIsInFront() throws {
        let (runtime, lifecycle) = Self.application([
            ("1", [Self.window("main"), Self.window("tool", kind: "tool", [.hidesWhenInactive: .bool(true)])]),
            ("2", [Self.window("main")]),
        ])
        let first = try Self.window("main", in: "1", of: runtime)
        let tool = try Self.window("tool", in: "1", of: runtime)
        let second = try Self.window("main", in: "2", of: runtime)
        XCTAssertFalse(lifecycle.isHiddenByScene(tool), "no scene in front yet")

        lifecycle.report(first, minimized: false, activated: true)
        _ = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertFalse(lifecycle.isHiddenByScene(tool))

        lifecycle.report(first, minimized: false, activated: false)
        lifecycle.report(second, minimized: false, activated: true)
        var moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertTrue(lifecycle.isHiddenByScene(tool))
        XCTAssertFalse(lifecycle.isHiddenByScene(second), "a window that does not hide")
        XCTAssertTrue(Self.names(moves.told).contains("1/tool stopped"))

        lifecycle.report(second, minimized: false, activated: false)
        lifecycle.report(first, minimized: false, activated: true)
        moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertFalse(lifecycle.isHiddenByScene(tool))
        XCTAssertEqual(Self.names(moves.told).filter { $0.hasPrefix("1/tool") }, ["1/tool resumed", "1/tool deactivated"])
    }

    /// A window that floats does so while the application is in front - and before it is told it is not - and
    /// sinks with it while another application is in use.
    func testAWindowFloatsWhileTheApplicationIsInFront() throws {
        let (runtime, lifecycle) = Self.application([
            ("1", [Self.window("main"), Self.window("tool", kind: "tool", [.floatsOnTop: .bool(true)])]),
        ])
        let main = try Self.window("main", in: "1", of: runtime)
        let tool = try Self.window("tool", in: "1", of: runtime)
        XCTAssertTrue(lifecycle.floats(tool))
        XCTAssertFalse(lifecycle.floats(main), "a window that does not say so")

        lifecycle.report(main, minimized: false, activated: true)
        _ = lifecycle.settle(windows: runtime.tree.root!.windows)
        lifecycle.report(main, minimized: false, activated: false)
        let moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertFalse(lifecycle.floats(tool))
        XCTAssertTrue(moves.standing, "the floating windows sink")
        XCTAssertEqual(WindowTraits(of: tool, in: lifecycle).floatsOnTop, false)
    }

    /// A scene whose main window is minimized is stopped, unless another of its windows is activated; a hidden
    /// application stops everything, whatever its windows do.
    func testAMinimizedMainWindowOrAHiddenApplicationStopsTheScene() throws {
        let (runtime, lifecycle) = Self.application([("1", [Self.window("main"), Self.window("tool", kind: "tool")])])
        let main = try Self.window("main", in: "1", of: runtime)
        let tool = try Self.window("tool", in: "1", of: runtime)

        lifecycle.report(main, minimized: true, activated: false)
        var moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertEqual(moves.phase, .inactive, "a window of it still stands on the screen")
        XCTAssertEqual(Self.names(moves.told), ["1 stopped", "1/main stopped", "1/tool deactivated"])

        lifecycle.report(tool, minimized: false, activated: true)
        moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertEqual(Self.names(moves.told), ["1 activated", "1/tool activated"])

        lifecycle.isHidden = true
        moves = lifecycle.settle(windows: runtime.tree.root!.windows)
        XCTAssertEqual(moves.phase, .background)
        XCTAssertEqual(Self.names(moves.told), ["1 stopped", "1/tool stopped"])
    }

    /// As the application ends, each scene's windows hear that they are going, then the scene.
    func testTheEndingTellsEachScenesWindowsThenTheScene() {
        let (runtime, _) = Self.application([
            ("1", [Self.window("main"), Self.window("tool", kind: "tool")]), ("2", [Self.window("main")]),
        ])

        XCTAssertEqual(Self.names(ApplicationLifecycle.ending(windows: runtime.tree.root!.windows)), [
            "1/main destroying", "1/tool destroying", "1 destroying", "2/main destroying", "2 destroying",
        ])
    }

    /// The core hears the phase the runtime settles, and the window's session moves with it.
    func testTheCoreAndTheWindowHearThePhase() throws {
        stateUIUseApp(PhasesApplication())
        let runtime = HostRuntime.still()
        runtime.core.connectScene()
        runtime.pump.turn()
        defer { HostBoundary.setApplicationPhase(.active) }
        let window = try XCTUnwrap(Scenes.shared.list.first).windowSession(SceneElement.mainKey)
        let element = try XCTUnwrap(runtime.tree.root?.windows.first)

        runtime.windowStateChanged(element, minimized: true, activated: false)
        runtime.settlePhases()
        XCTAssertEqual(StandardEnvironment.application.phase, .background)
        XCTAssertEqual(window.phase, .stopped)

        runtime.windowStateChanged(element, minimized: false, activated: true)
        runtime.settlePhases()
        XCTAssertEqual(StandardEnvironment.application.phase, .active)
        XCTAssertEqual(window.phase, .activated)
    }

    /// A phase settled in the middle of the user's transaction - as a toolkit tells one while the host shows a
    /// window - is heard once it is over.
    func testAPhaseSettledInsideATransactionWaitsForItsEnd() throws {
        stateUIUseApp(PhasesApplication())
        let runtime = HostRuntime.still()
        runtime.core.connectScene()
        runtime.pump.turn()
        defer { HostBoundary.setApplicationPhase(.active) }
        let window = try XCTUnwrap(Scenes.shared.list.first).windowSession(SceneElement.mainKey)
        let element = try XCTUnwrap(runtime.tree.root?.windows.first)

        runtime.pump.performUserTransaction {
            runtime.windowStateChanged(element, minimized: true, activated: false)
            runtime.settlePhases()
            XCTAssertNotEqual(window.phase, .stopped, "heard in the middle of the transaction")
        }
        XCTAssertEqual(window.phase, .stopped)
    }

    /// An application of `scenes`, each its windows, and the lifecycle a runtime holds for it.
    private static func application(_ scenes: [(String, [HostPatch])]) -> (HostRuntime, ApplicationLifecycle) {
        let runtime = HostRuntime.still()
        var root = HostPatch(id: .manual("application"), type: .application)
        root.children = .arranged(scenes.map { name, windows in
            var scene = HostPatch(id: .manual(name), type: .scene)
            scene.children = .arranged(windows)
            return scene
        })
        runtime.tree.apply(root, complete: true)
        return (runtime, runtime.lifecycle)
    }

    /// A window element named `name`, of `kind` where it is not a scene's main window, saying `properties`.
    private static func window(_ name: String, kind: String? = nil, _ properties: [Prop: HostValue] = [:]) -> HostPatch {
        var window = HostPatch(id: .manual(name), type: .window)
        window.properties = properties
        if let kind { window.properties[.windowType] = .name(kind) }
        return window
    }

    /// The window `name` of scene `scene`.
    private static func window(_ name: String, in scene: String, of runtime: HostRuntime) throws -> MountedElement {
        try XCTUnwrap(runtime.tree.root?.first(id: .manual(scene))?.first(id: .manual(name)))
    }

    /// What was told, as "scene event" and "scene/window event".
    private static func names(_ told: [ApplicationLifecycle.Told]) -> [String] {
        told.map { each in
            let name = { (element: MountedElement?) in
                guard case .manual(let name)? = element?.id else { return "?" }
                return name
            }
            let scene = each.element.enclosing(type: .scene)
            let path = each.element.type == .scene ? name(scene) : "\(name(scene))/\(name(each.element))"
            return "\(path) \(each.event.name)"
        }
    }
}

private struct PhasesApplication: Application {
    var scene: any Scene { PhasesWindow() }
}

private struct PhasesWindow: Window {
    var page: any Page { Label("phases") }
}

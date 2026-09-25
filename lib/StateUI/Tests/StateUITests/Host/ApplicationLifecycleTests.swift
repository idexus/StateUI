// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// The application's phase as a toolkit tells it, and what its scene and its window hear of it.
final class ApplicationLifecycleTests: XCTestCase {
    private typealias Told = ApplicationLifecycle.Told

    /// Each phase is told to the scene, then to the window; a window coming back from the background hears first,
    /// once, that it resumed; a phase the application stands in tells nothing.
    func testEachPhaseIsToldToTheSceneThenTheWindow() {
        func told(_ event: Event) -> [Told] {
            [Told(element: .scene, event: event), Told(element: .window, event: event)]
        }
        var lifecycle = ApplicationLifecycle()

        XCTAssertEqual(lifecycle.enter(.active), told(.activated))
        XCTAssertNil(lifecycle.enter(.active), "the phase it stands in tells nothing")
        XCTAssertEqual(lifecycle.enter(.inactive), told(.deactivated))
        XCTAssertEqual(lifecycle.enter(.background), told(.stopped))
        XCTAssertEqual(lifecycle.enter(.inactive), [Told(element: .window, event: .resumed)] + told(.deactivated))
        XCTAssertEqual(lifecycle.enter(.active), told(.activated), "resumed once")
        XCTAssertEqual(lifecycle.phase, .active)
        XCTAssertEqual(ApplicationLifecycle.ending, [
            Told(element: .window, event: .destroying), Told(element: .scene, event: .destroying),
        ])
    }

    /// The core hears the phase the runtime is told, and the window's session moves with it.
    @MainActor
    func testTheCoreAndTheWindowHearThePhase() throws {
        stateUIUseApp(PhasesApplication())
        let runtime = HostRuntime.still()
        runtime.core.connectScene()
        runtime.pump.turn()
        defer { StateUIHost.setApplicationPhase(.active) }
        let window = try XCTUnwrap(Scenes.shared.list.first).windowSession(SceneElement.mainKey)

        runtime.enterPhase(.background)
        XCTAssertEqual(StandardEnvironment.application.phase, .background)
        XCTAssertEqual(window.phase, .stopped)

        runtime.enterPhase(.active)
        XCTAssertEqual(StandardEnvironment.application.phase, .active)
        XCTAssertEqual(window.phase, .activated)
    }

    /// A phase told in the middle of the user's transaction - as a toolkit tells one while the host shows a window -
    /// is heard once it is over.
    @MainActor
    func testAPhaseToldInsideATransactionWaitsForItsEnd() throws {
        stateUIUseApp(PhasesApplication())
        let runtime = HostRuntime.still()
        runtime.core.connectScene()
        runtime.pump.turn()
        defer { StateUIHost.setApplicationPhase(.active) }
        let window = try XCTUnwrap(Scenes.shared.list.first).windowSession(SceneElement.mainKey)

        runtime.pump.performUserTransaction {
            runtime.enterPhase(.background)
            XCTAssertNotEqual(window.phase, .stopped, "heard in the middle of the transaction")
        }
        XCTAssertEqual(window.phase, .stopped)
    }
}

private struct PhasesApplication: Application {
    var scene: any Scene { PhasesWindow() }
}

private struct PhasesWindow: Window {
    var page: any Page { Label("phases") }
}

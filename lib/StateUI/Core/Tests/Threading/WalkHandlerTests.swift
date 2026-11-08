// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class WalkHandlerTests: XCTestCase {
    func testRemovingAWatchCancelsItsRunningHandler() async throws {
        let gate = Gate(.runConcurrently)
        let renders = Renders()
        func tree(_ value: Int) -> Node {
            Text("same").onChanged(value, gate: gate) {
                try await Task.sleep(for: .seconds(60))
            }.node
        }
        renders.render(tree(0))
        renders.render(tree(1))
        XCTAssertTrue(gate.isBusy)
        renders.render(Text("same").node)
        await gate.waitWhileBusy()
        XCTAssertFalse(gate.isBusy, "a removed onChanged still owns a running handler")
        await gate.endEveryRun()
    }

    func testRemovingAVisualStateListenerCancelsItsRunningHandler() async throws {
        let gate = Gate(.runConcurrently)
        let renders = Renders()
        func tree(_ enabled: Bool, listening: Bool) -> Node {
            let control = Button("same").isEnabled(enabled)
                .visualState(.disabled) { $0.opacity(0.5) }
            if listening {
                return control.onVisualStateChanged(gate: gate) { _ in
                    try await Task.sleep(for: .seconds(60))
                }.node
            }
            return control.node
        }
        renders.render(tree(true, listening: true))
        renders.render(tree(false, listening: true))
        XCTAssertTrue(gate.isBusy)
        renders.render(tree(false, listening: false))
        await gate.waitWhileBusy()
        XCTAssertFalse(gate.isBusy, "a removed visual-state listener still owns a running handler")
        await gate.endEveryRun()
    }

    func testRemovingANativeEventCancelsItsRunningHandler() async throws {
        let gate = Gate(.runConcurrently)
        let renders = Renders()
        let patch = renders.render(Button("same").onClicked(gate: gate) {
            try await Task.sleep(for: .seconds(60))
        }.node)
        let clicked = try XCTUnwrap(patch.events?["clicked"])
        renders.fire(clicked)
        XCTAssertTrue(gate.isBusy)
        renders.render(Button("same").node)
        await gate.waitWhileBusy()
        XCTAssertFalse(gate.isBusy)
        await gate.endEveryRun()
    }

    func testARetiredOwnerCannotStartQueuedWork() {
        let owner = RunOwner()
        var ran = false
        let fired = Fired(run: { ran = true }, owner: owner)
        owner.orphan()

        Renderer.shared.run(fired)

        XCTAssertFalse(ran, "queued work must not revive a removed handler")
    }

    func testChangingTheWatchedTypeEndsThePreviousHandler() async throws {
        let gate = Gate(.runConcurrently)
        let renders = Renders()
        func number(_ value: Int) -> Node {
            Text("same").onChanged(value, gate: gate) {
                try await Task.sleep(for: .seconds(60))
            }.node
        }
        renders.render(number(0))
        renders.render(number(1))
        XCTAssertTrue(gate.isBusy)

        renders.render(Text("same").onChanged("new", gate: gate) {
            try await Task.sleep(for: .seconds(60))
        }.node)
        await gate.waitWhileBusy()
        XCTAssertFalse(gate.isBusy, "a different watched type begins a different registration")
        await gate.endEveryRun()
    }
}

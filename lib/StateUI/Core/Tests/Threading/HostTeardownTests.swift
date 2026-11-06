// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

@MainActor
final class HostTeardownTests: XCTestCase {
    func testAnOwnedRunIsFollowedBeforeItsImmediateTaskIsInHand() async {
        let owner = RunOwner()
        let ending = HostTeardown()
        var finishedInside = true
        var release: CheckedContinuation<Void, Never>?
        let task = owner.ownRuns.start({
            ending.collect { owner.orphan() }
            finishedInside = ending.isFinished
            await withCheckedContinuation { release = $0 }
        }, .runConcurrently, payload: nil, owner: owner)

        XCTAssertFalse(finishedInside, "the retired owner's task already belongs to the teardown")
        XCTAssertFalse(ending.isFinished)
        release?.resume()
        await task.value
        for _ in 0..<100 { if ending.isFinished { break }; await Task.yield() }
        XCTAssertTrue(ending.isFinished)
    }
}

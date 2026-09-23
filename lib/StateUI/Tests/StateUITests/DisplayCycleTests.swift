// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// One frame of the display, in the order every runtime keeps.
final class DisplayCycleTests: XCTestCase {
    /// A state channel's step, a described property's step and the core's changes are presented in one walk.
    @MainActor
    func testAFramePresentsEverythingItMovedInOneWalk() {
        let walker = Walker()
        let channels = StateChannels(walker: walker)
        let described = DescribedMotion(walker: walker)
        let cycle = DisplayCycle(
            core: CoreLink(),
            clock: HandClock(),
            walker: walker,
            stateChannels: channels,
            describedMotion: described,
            layoutMotion: LayoutMotion(walker: walker, now: { 0 }, reducesMotion: { false }),
            reducesMotion: { false })
        let presenter = CountingPresenter()
        cycle.presenter = presenter

        let travelling = HostJourney(
            value: [0], destination: [100], velocity: [0], motion: .eased(400), completion: nil, stopped: 0)
        _ = channels.presentedValue(
            for: HostStateBinding(state: 9, mode: .out, kind: .property),
            from: StateUIHost.value(of: travelling),
            now: 0,
            reducesMotion: false)
        described.receive(
            key: DescribedKey(mount: 1, property: .opacity),
            standing: .number(0),
            target: .number(1),
            motion: .eased(400),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        cycle.frame(now: 100)

        XCTAssertEqual(presenter.walks, 1)
    }
}

/// A clock the test winds by hand.
@MainActor
private final class HandClock: FrameClock {
    let now: () -> Double = { 0 }
    var held = false
}

/// A presenter that counts the walks a frame asks of the mounted tree.
@MainActor
private final class CountingPresenter: FramePresenter {
    var walks = 0
    var wantsFrames: Bool { false }

    func commitUserReports(now: Double) {}

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        walks += 1
    }

    func renderIfNeeded() {}
}

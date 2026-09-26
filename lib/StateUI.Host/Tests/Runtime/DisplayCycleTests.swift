// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// One frame of the display, in the order every runtime keeps.
final class DisplayCycleTests: XCTestCase {
    /// A state channel, a described property and the core's changes are presented in one walk.
    @MainActor
    func testAFramePresentsEverythingItMovedInOneWalk() {
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        let described = DescribedMotion(animator: animator)
        let cycle = DisplayCycle(
            core: CoreLink(),
            clock: HandClock(),
            animator: animator,
            stateChannels: channels,
            describedMotion: described,
            layoutMotion: LayoutMotion(animator: animator, now: { 0 }, reducesMotion: { false }),
            reducesMotion: { false })
        let presenter = CountingPresenter()
        cycle.presenter = presenter

        let travelling = HostJourney(
            value: [0], destination: [100], velocity: [0], motion: .eased(400), completion: nil, stopped: 0)
        _ = channels.presentedValue(
            for: HostStateBinding(state: 9, mode: .out, kind: .property),
            from: HostBoundary.value(of: travelling),
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

    /// The frame clock is held from the moment something starts moving - a property, a layout's child, a scroller
    /// - and let go on the frame the last of them comes to rest.
    @MainActor
    func testTheClockIsHeldOnlyWhileSomethingMoves() {
        let runtime = HostRuntime.still()
        let presenter = CountingPresenter()
        runtime.displayCycle.presenter = presenter
        runtime.displayCycle.hold()
        XCTAssertFalse(runtime.clock.held, "nothing moves")

        runtime.tree.receiveProperty(
            mount: 1, property: .opacity, standing: .number(0), target: .number(1), motion: .eased(200, .linear))
        XCTAssertTrue(runtime.clock.held, "a property's animation holds it as it starts")
        runtime.displayCycle.frame(now: 100)
        XCTAssertTrue(runtime.clock.held, "and while it runs")
        runtime.displayCycle.frame(now: 200)
        XCTAssertFalse(runtime.clock.held, "and lets go on the frame it lands")

        let child = Placed()
        let travels = Arrangement(law: .eased(200, .linear), lanes: .all)
        runtime.layoutMotion.place(
            child, mount: 2, at: Rect(x: 0, y: 0, width: 10, height: 10), stated: [], fadeIn: nil, in: travels)
        XCTAssertFalse(runtime.clock.held, "a child standing at its place does not move")
        runtime.layoutMotion.place(
            child, mount: 2, at: Rect(x: 0, y: 50, width: 10, height: 10), stated: [], fadeIn: nil, in: travels)
        XCTAssertTrue(runtime.clock.held, "a child on its way to its place holds it")
        runtime.displayCycle.frame(now: 400)
        XCTAssertFalse(runtime.clock.held)

        presenter.wantsFrames = true
        runtime.displayCycle.frame(now: 500)
        XCTAssertTrue(runtime.clock.held, "a scroller still moving holds it")
        presenter.wantsFrames = false
        runtime.displayCycle.frame(now: 600)
        XCTAssertFalse(runtime.clock.held)
    }
}

/// A view that stands where it is placed.
@MainActor
private final class Placed: PlacedView {
    var placedFrame = Rect(x: 0, y: 0, width: 0, height: 0)
}

/// A clock the test winds by hand.
@MainActor
private final class HandClock: FrameClock {
    let now: () -> Double = { 0 }
    var held = false
    var onFrame: ((Double) -> Void)?
}

/// A presenter that counts the walks a frame asks of the mounted tree, with a scroller that moves while it says.
@MainActor
private final class CountingPresenter: FramePresenter {
    var walks = 0
    var wantsFrames = false

    func commitUserReports(now: Double) {}

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        walks += 1
    }

    func renderIfNeeded() {}
}

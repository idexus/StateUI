// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// One frame of the display, in the order every runtime keeps.
@MainActor
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
            sidebarSlide: SidebarSlide(animator: animator, now: { 0 }, reducesMotion: { false }),
            reducesMotion: { false })
        let presenter = CountingPresenter()
        cycle.presenter = presenter

        let travelling = HostJourney(
            value: [0], destination: [100], velocity: [0], motion: .eased(.milliseconds(400)), completion: nil, stopped: 0)
        _ = channels.presentedValue(
            for: HostStateBinding(state: 9, mode: .out, kind: .property, laneKind: .number),
            from: HostBoundary.value(of: travelling),
            now: 0,
            reducesMotion: false)
        described.receive(
            key: DescribedKey(mount: 1, property: .opacity),
            standing: .number(0),
            target: .number(1),
            motion: .eased(.milliseconds(400)),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        cycle.frame(now: 100)

        XCTAssertEqual(presenter.walks, 1)
    }

    /// Advancing the animations alone - what a host's test winds - lets the clock go as a frame does, once the last
    /// animation lands.
    @MainActor
    func testAdvancingTheAnimationsLetsTheClockGoAsAFrameDoes() {
        let runtime = HostRuntime.still()
        let presenter = CountingPresenter()
        runtime.displayCycle.presenter = presenter
        runtime.tree.receiveProperty(
            mount: 1, property: .opacity, standing: .number(0), target: .number(1), motion: .eased(.milliseconds(200), .linear))
        XCTAssertTrue(runtime.clock.held)

        runtime.displayCycle.advanceAnimations(now: 300, reducesMotion: false)

        XCTAssertFalse(runtime.clock.held, "nothing moves any more")
        withExtendedLifetime(presenter) {}
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
            mount: 1, property: .opacity, standing: .number(0), target: .number(1), motion: .eased(.milliseconds(200), .linear))
        XCTAssertTrue(runtime.clock.held, "a property's animation holds it as it starts")
        runtime.displayCycle.frame(now: 100)
        XCTAssertTrue(runtime.clock.held, "and while it runs")
        runtime.displayCycle.frame(now: 200)
        XCTAssertFalse(runtime.clock.held, "and lets go on the frame it lands")

        let child = Placed()
        let travels = Arrangement(law: .eased(.milliseconds(200), .linear), lanes: .all)
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

    /// The display's frames come stamped on its clock and a turn between them on the runtime's own: a frame stamped
    /// before the last turn's time moves nothing back.
    @MainActor
    func testTheCyclesTimeNeverRunsBack() {
        let runtime = HostRuntime.still()
        var seen: [Double] = []
        runtime.sidebarSlide.slide(1, from: 0, shown: true) { shown, _ in seen.append(shown) }
        runtime.displayCycle.frame(now: 100)
        runtime.displayCycle.drain(now: 130)
        runtime.displayCycle.frame(now: 116)

        XCTAssertEqual(seen, seen.sorted(), "nothing slides back")
    }

    /// What a toolkit's layout pass says takes no time: the pass lays out the frame the cycle last ran at, so what
    /// it reports moves no travel on, though the runtime's clock went on. A slide stepped on there would narrow the
    /// page again in the same pass, and its report step it on again, until the slide rests within one frame.
    @MainActor
    func testWhatALayoutPassSaysTakesNoTime() throws {
        stateUIUseApp(ReadTravelApplication())
        let clock = WoundClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        let slider = try XCTUnwrap(runtime.tree.root?.first(id: .manual("slider")))
        let up = try XCTUnwrap(runtime.tree.root?.first(id: .manual("up"))?.handler(.clicked))
        let view = LaidOut(try XCTUnwrap(runtime.tree.root?.first(id: .manual("read"))), in: runtime)
        runtime.frames.follow(view, order: 1, reads: true)

        runtime.pump.dispatch(up)
        clock.time = 100
        runtime.displayCycle.frame(now: 100)
        XCTAssertEqual(slider.number(.value) ?? .nan, 0.5, accuracy: 1e-9, "half way up")

        clock.time = 150
        view.width = 300
        runtime.frames.laidOut()
        XCTAssertTrue(runtime.frames.reportLaidOut(), "the layout pass said where the view stands")
        XCTAssertEqual(slider.number(.value) ?? .nan, 0.5, accuracy: 1e-9, "the travel stands where the frame left it")

        clock.time = 175
        runtime.displayCycle.frame(now: 175)
        XCTAssertEqual(slider.number(.value) ?? .nan, 0.875, accuracy: 1e-9, "and goes on on the display's next frame")
    }

    /// A STATE AN ELEMENT WEARS HAS ITS CHANNEL from the moment it is worn, whatever its view reads: the host layer
    /// walks it and tells the core every frame - a layout engine's phase, which no view draws, included.
    @MainActor
    func testAWornStateOpensItsChannelThoughNoViewReadsIt() throws {
        stateUIUseApp(WornApplication())
        let runtime = HostRuntime(clock: WoundClock(), reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()

        var worn: Set<Int32> = []
        func walk(_ element: MountedElement) {
            for binding in element.driven.values where binding.kind == .property && binding.mode != .in {
                worn.insert(binding.state)
            }
            element.children.forEach(walk)
        }
        try walk(XCTUnwrap(runtime.tree.root))

        XCTAssertFalse(worn.isEmpty, "the layout's element wears its phase")
        XCTAssertEqual(runtime.stateChannels.count, worn.count, "a channel for every state worn, none read")
    }

    /// A handler's write in the turn a state's travel lands sends the travel on: the frame lands the travel and
    /// reports the destination before the write, which stands and crosses in the same frame.
    @MainActor
    func testAWriteInTheTurnATravelLandsSendsItOn() throws {
        stateUIUseApp(TravelApplication())
        let clock = WoundClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        let slider = try XCTUnwrap(runtime.tree.root?.first(id: .manual("slider")))
        let up = try XCTUnwrap(runtime.tree.root?.first(id: .manual("up"))?.handler(.clicked))
        let down = try XCTUnwrap(runtime.tree.root?.first(id: .manual("down"))?.handler(.clicked))

        runtime.pump.dispatch(up)
        clock.time = 100
        runtime.displayCycle.frame(now: 100)
        XCTAssertEqual(slider.number(.value) ?? .nan, 0.5, accuracy: 1e-9, "half way up")

        clock.time = 250
        runtime.pump.dispatch(down)
        XCTAssertTrue(runtime.clock.held, "the travel goes on to the new destination")

        clock.time = 500
        runtime.displayCycle.frame(now: 500)
        XCTAssertEqual(slider.number(.value) ?? .nan, 0.25, accuracy: 1e-9, "where the handler sent it")
    }
}

/// A layout engine, whose element wears its phase and whose view draws none of it.
private struct WornApplication: Application {
    var body: some Scene {
        WindowGroup {
            LayoutEngine([0]) { _ in Rectangle(.red) } placements: { _, _ in [] }
        }
    }
}

/// A slider travelling where two buttons send its state.
private struct TravelApplication: Application {
    var body: some Scene {
        WindowGroup { TravelPage() }
    }
}

private struct TravelPage: View {
    @State(motion: .eased(.milliseconds(200), .linear)) private var level = 0.0

    var body: some View {
        VStack {
            Slider($level).id("slider")
            Button("Up").onClicked { level = 1 }.id("up")
            Button("Down").onClicked { level = 0.25 }.id("down")
        }
    }
}

/// A slider travelling where a button sends its state, in a stack whose frame the page reads.
private struct ReadTravelApplication: Application {
    var body: some Scene {
        WindowGroup { ReadTravelPage() }
    }
}

private struct ReadTravelPage: View {
    @State(motion: .eased(.milliseconds(200), .linear)) private var level = 0.0
    @State private var room = Rect(0, 0, 0, 0)

    var body: some View {
        VStack {
            VStack {
                Slider($level).id("slider")
                Button("Up").onClicked { level = 1 }.id("up")
            }
            .frame($room)
            .id("read")
        }
    }
}

/// An element's view a test lays out by hand, saying where it stands.
@MainActor
private final class LaidOut: FrameReporter {
    let element: MountedElement
    unowned let runtime: HostRuntime
    var width = 100.0

    init(_ element: MountedElement, in runtime: HostRuntime) {
        self.element = element
        self.runtime = runtime
    }

    func reportFrame() {
        let place = Rect(x: 0, y: 0, width: width, height: 50)
        element.reportFrame(
            MountedElement.frameNumbers(place: place, corner: Point(x: 0, y: 0), content: Point(x: 0, y: 0)),
            in: runtime)
    }
}

/// A clock a test winds by hand.
@MainActor
private final class WoundClock: FrameClock {
    var time = 0.0
    var held = false
    var onFrame: ((Double) -> Void)?
    var now: () -> Double { { [unowned self] in time } }
}

/// A view that stands where it is placed.
@MainActor
private final class Placed: PlacedView {
    var placedFrame = Rect(x: 0, y: 0, width: 0, height: 0)
}

/// A clock no display drives.
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

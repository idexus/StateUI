// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Every sample visited and left, over the core and the host layer: what stands alive after the way back is what
// stood before the visit. A host's own suite proves its toolkit lets go of each view; this walk proves the gallery's
// pages, states and runs do.

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import GalleryUI

/// The gallery walked sample by sample, the live counts read back on each group's page.
@MainActor
final class LeakWalkTests: XCTestCase {
    /// EVERY SAMPLE, VISITED AND LEFT, LEAVES NOTHING ALIVE: the rendered elements, the runs, the native halves and
    /// the state channels stand where they stood on the group's page before the visit.
    func testEverySampleLeftLeavesNothingAlive() async throws {
        let walk = Walk()
        var visited = 0
        var unopened: [String] = []
        var outlived: [String] = []

        for group in Catalog(nav: Navigation(), style: SessionStyle(), bar: WindowBarState(), log: WindowLog()).groups {
            try walk.tap(handle("menu", group.title))
            await walk.settle()
            let base = walk.alive

            for sample in group.samples {
                try walk.tap(handle("row", sample.title))
                await walk.settle()
                if walk.alive.elements <= base.elements { unopened.append("\(group.route)/\(sample.id)") }
                try walk.back()
                await walk.settle()
                visited += 1
                let after = walk.alive
                if after != base { outlived.append("\(group.route)/\(sample.id): \(base) -> \(after)") }
            }
        }

        XCTAssertGreaterThan(visited, 100, "the walk reached the gallery's samples")
        XCTAssertEqual(unopened, [], "a tap on these rows opened no page")
        XCTAssertEqual(outlived, [], "a sample left something alive behind it")
    }
}

/// What stands alive: the core's rendered elements and runs, the native halves, the state channels.
private struct Alive: Equatable, CustomStringConvertible {
    let elements: Int
    let runs: Int
    let halves: Int
    let channels: Int

    var description: String { "elements \(elements), runs \(runs), halves \(halves), channels \(channels)" }
}

/// The gallery running over the core and the host layer on a clock wound by hand, its windows shown by the host
/// layer's own presentation and its native halves counted.
@MainActor
private final class Walk: HostPresenter {
    private(set) var runtime: HostRuntime!
    private let clock = WalkClock()
    private let roster = WindowRoster<WindowPresentation>()
    fileprivate var halves = 0

    init() {
        stateUIUseApp(GalleryApp())
        runtime = HostRuntime(
            clock: clock, reducesMotion: { false }, makeNative: { [unowned self] _ in WalkedHalf(self) },
            log: { _ in })
        runtime.presenter = self
        runtime.connectWindow()
        runtime.pump.turn()
    }

    var alive: Alive {
        let tally = HostBoundary.tally
        return Alive(elements: tally.alive, runs: tally.runs, halves: halves, channels: runtime.stateChannels.count)
    }

    /// The user taps the view the gallery names `identifier`.
    func tap(_ identifier: String) throws {
        let view = try XCTUnwrap(runtime.tree.root.flatMap { Self.find(identifier, in: $0) }, identifier)
        view.hear(.tap(run: 1), in: runtime)
    }

    /// The first view under `element`, itself first, the gallery names `identifier`.
    private static func find(_ identifier: String, in element: MountedElement) -> MountedElement? {
        if element.value(.accessibilityIdentifier)?.string == identifier { return element }
        for child in element.children {
            if let found = find(identifier, in: child) { return found }
        }
        return nil
    }

    /// The user goes back the way the window offers.
    func back() throws {
        let (window, presentation) = try XCTUnwrap(roster.windows.first)
        runtime.goBack(try XCTUnwrap(presentation.wayBack, "no way back"), in: window)
    }

    /// A second of frames, each with its turn, and the UI thread's work run between them.
    func settle() async {
        for _ in 0..<60 {
            clock.time += 1_000 / 60
            runtime.displayCycle.frame(now: clock.time)
            runtime.pump.turn()
            await Task.yield()
        }
    }

    func presentRendered(touchedChrome: Bool) {
        guard touchedChrome else { return }
        roster.update(root: runtime.tree.root, make: { _ in WindowPresentation() }, close: { _ in })
        for (window, presentation) in roster.windows { _ = presentation.show(window, in: runtime.lifecycle) }
    }

    func presentFrame(movedChrome: Bool) {}

    /// Answers the act as every host answers what it cannot perform: a run awaiting it goes on, and ends.
    func perform(_ call: HostActCall) {
        if let completion = call.completion { runtime.core.fail(completion, reason: "the walk performs no act") }
    }
    func focus(_ element: MountedElement) {}
}

/// A native half with nothing behind it, counted while it stands.
@MainActor
private final class WalkedHalf: NativeElement {
    private unowned let walk: Walk
    let presentsView = true

    init(_ walk: Walk) {
        self.walk = walk
        walk.halves += 1
    }

    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {}
    func presentFrame(_ changed: Set<Prop>) {}
    func arrangeChildren() {}
    func invalidateMeasurements() {}
    func configureLayoutMotion() {}
    func directionChanged() {}

    func leave() {
        walk.halves -= 1
    }
}

/// The clock a walk winds by hand.
@MainActor
private final class WalkClock: FrameClock {
    var time = 0.0
    var held = false
    var onFrame: ((Double) -> Void)?
    var now: () -> Double { { [unowned self] in time } }
}

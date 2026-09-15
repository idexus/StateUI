// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitDisplayCycleTests: XCTestCase {
    /// A frame's order lives in one place: only the display cycle steps the
    /// walker and runs the core's cycle, so no path of the host walks a trip
    /// or drains a cycle in an order of its own.
    func testOnlyTheDisplayCycleStepsTheWalkerAndRunsTheCoresCycle() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // StateUI.AppKit
            .appendingPathComponent("Sources")
        let steps = ["walker.step(", "core.cycle("]
        var found: [String] = []

        let names = try FileManager.default.contentsOfDirectory(atPath: sources.path).sorted()
        for name in names where name.hasSuffix(".swift") && name != "AppKitDisplayCycle.swift" {
            let text = try String(contentsOf: sources.appendingPathComponent(name), encoding: .utf8)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

            for (number, line) in lines.enumerated()
            where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                for step in steps where line.contains(step) {
                    found.append("\(name):\(number + 1): \(step)")
                }
            }
        }

        XCTAssertEqual(found, [], "a frame is AppKitDisplayCycle's, in its one order")
    }

    /// Everything a frame moved is presented in one walk of the mounted tree -
    /// a state channel's step, a described property's step and the core's
    /// changes together - so each ancestor arranges once a frame.
    @MainActor
    func testAFramePresentsEverythingItMovedInOneWalk() {
        let walker = AppKitWalker()
        let channels = AppKitStateChannels(walker: walker)
        let described = AppKitDescribedMotion(walker: walker)
        let cycle = AppKitDisplayCycle(
            core: AppKitCoreLink(),
            clock: AppKitFrameClock(now: { 0 }),
            walker: walker,
            stateChannels: channels,
            describedMotion: described,
            reducesMotion: { false })
        let presenter = CountingPresenter()
        cycle.presenter = presenter

        let travelling = HostJourney(
            value: [0], destination: [100], velocity: [0],
            motion: .eased(400), completion: nil, stopped: 0)
        _ = channels.presentedValue(
            for: HostStateBinding(state: 9, mode: .out, kind: .property),
            from: StateUIHost.value(of: travelling),
            now: 0,
            reducesMotion: false)
        described.receive(
            key: AppKitDescribedKey(mount: 1, property: .opacity),
            standing: .number(0),
            target: .number(1),
            transition: HostTransition(motion: .eased(400)),
            now: 0,
            reducesMotion: false)
        _ = channels.takeOutputs()

        cycle.frame(now: 100)

        XCTAssertEqual(presenter.walks, 1)
    }
}

/// A presenter that counts the walks a frame asks of the mounted tree.
@MainActor
private final class CountingPresenter: AppKitFramePresenter {
    var walks = 0
    var wantsFrames: Bool { false }

    func commitReaderReports(now: Double) {}

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        walks += 1
    }

    func renderIfNeeded() {}
}
#endif

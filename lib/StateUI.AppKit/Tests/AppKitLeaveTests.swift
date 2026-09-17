// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// An element that leaves the tree is detached from every part of the runtime
/// as it leaves: nothing waits for a walk of the whole tree to let it go.
final class AppKitLeaveTests: XCTestCase {
    private let state: Int32 = 5

    /// Labels whose opacity wears one state, under a stack.
    private func labels(_ names: [String]) -> HostPatch {
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged(names.map { name in
            var label = HostPatch(id: .manual(name), type: .label)
            label.driven = .replace([
                .opacity: HostStateBinding(state: state, mode: .out, kind: .property),
            ])
            return label
        })
        return root
    }

    private func journey(from value: Double, to destination: Double) -> HostStateValue {
        StateUIHost.value(of: HostJourney(
            value: [value],
            destination: [destination],
            velocity: [0],
            motion: .eased(200, .linear),
            completion: nil,
            stopped: 0))
    }

    /// One state is one channel however many controls wear it: it stays while
    /// any of them does, and goes when the last one leaves.
    @MainActor
    func testAChannelGoesWhenTheLastControlWearingItLeaves() {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { 0 },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(labels(["a", "b"]))
        renderer.applyStateForTesting(state, value: journey(from: 1, to: 1))
        XCTAssertEqual(renderer.channelCountForTesting, 1)

        renderer.applyForTesting(labels(["b"]))
        XCTAssertEqual(renderer.channelCountForTesting, 1, "the other label still wears it")

        renderer.applyForTesting(labels([]))
        XCTAssertEqual(renderer.channelCountForTesting, 0, "the last one took it with it")
    }

    /// A channel still moving when its last control leaves runs to its truthful
    /// landing, and only then goes.
    @MainActor
    func testAMovingChannelWhoseLastControlLeftLandsAndThenGoes() {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(labels(["a"]))
        renderer.applyStateForTesting(state, value: journey(from: 0, to: 1))
        XCTAssertTrue(renderer.tripsMovingForTesting)

        renderer.applyForTesting(labels([]))
        XCTAssertEqual(renderer.channelCountForTesting, 1, "it goes on to where it was sent")

        now = 200
        renderer.stepTripsForTesting()
        XCTAssertEqual(renderer.channelCountForTesting, 0, "and goes once it has landed")
    }
}
#endif

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A drag's dismissal as a declaration: what the host is handed of it, what is refused, what `onDismissed` is told,
// and how a host learns that every run the event started has ended.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class InteractionDismissalTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// The drag the host was handed for the rectangle of `patch`.
    private func drag(_ patch: HostPatch) -> HostDrag? {
        guard case .replace(let program)? = (patch.type == .rectangle ? patch : patch.first(.rectangle))?.interaction
        else { return nil }
        return program.drag
    }

    /// A DISMISSAL IS HANDED WITH THE DRAG IT IS SAID OF: its ways, its threshold and its law, a spring unless said.
    func testADismissalIsHandedWithItsDrag() throws {
        let patch = Renders().render(
            Rectangle()
                .interaction(.drag(.vertical, begins: .directional).dismissal(directions: .up, threshold: 120))
                .id("card").node)

        XCTAssertEqual(drag(patch), HostDrag(
            axes: .vertical, begins: .directional,
            dismissal: HostDismissal(directions: .up, threshold: 120, motion: .spring())))

        let eased = Renders().render(
            Rectangle()
                .interaction(.drag(.both).dismissal(
                    directions: [.left, .right], threshold: 80, motion: .eased(.milliseconds(200))))
                .id("card").node)
        XCTAssertEqual(drag(eased)?.dismissal, HostDismissal(
            directions: [.left, .right], threshold: 80, motion: .eased(.milliseconds(200))))
    }

    /// A DISMISSAL SAID OF NO DRAG, OF NO DIRECTION OR OF NO THRESHOLD IS REFUSED: the drag stands without it.
    func testADismissalOfNothingIsRefused() throws {
        let offset = State(wrappedValue: 0.0)
        Renders().render(
            Rectangle()
                .interaction(.value(offset.projectedValue, input: .translation(.horizontal))
                    .dismissal(directions: .up, threshold: 10))
                .id("valued").node)
        XCTAssertTrue(hasComplained("A dismissal is said of a drag"))

        let none = Renders().render(
            Rectangle().interaction(.drag(.both).dismissal(directions: [], threshold: 10)).id("none").node)
        XCTAssertTrue(hasComplained("at least one direction"))
        XCTAssertEqual(drag(none), HostDrag(axes: .both, begins: .immediately), "the drag stands")

        let flat = Renders().render(
            Rectangle().interaction(.drag(.both).dismissal(directions: .up, threshold: 0)).id("flat").node)
        XCTAssertNil(drag(flat)?.dismissal)
        let endless = Renders().render(
            Rectangle().interaction(.drag(.both).dismissal(directions: .up, threshold: .infinity)).id("endless").node)
        XCTAssertNil(drag(endless)?.dismissal)
    }

    /// `onDismissed` IS TOLD THE WAY THE VIEW LEFT AND THE HAND'S SPEED.
    func testOnDismissedIsToldTheWayAndTheSpeed() throws {
        let renders = Renders()
        var told: [Dismissal] = []
        let patch = renders.render(Rectangle().onDismissed { told.append($0) }.node)

        renders.fire(
            patch.events?["dismissed"] ?? -1, with: [SwipeDirection.up.propValue, Point(x: 10, y: -900).propValue])

        XCTAssertEqual(told, [Dismissal(direction: .up, velocity: Point(x: 10, y: -900))])
    }

    /// AN EVENT SAYS WHEN ITS RUNS ENDED: after a handler that returns, and only after one that awaits has ended -
    /// what a host waits for before it shows a dismissed view nobody removed back in its place.
    func testAnEventSaysWhenEveryRunItStartedEnded() async throws {
        let renders = Renders()
        var said: [String] = []
        let (waits, lets) = AsyncStream<Void>.makeStream()
        let patch = renders.render(
            Rectangle()
                .onDismissed { _ in said.append("returned") }
                .onDismissed(policy: .runConcurrently) { _ in
                    for await _ in waits { break }
                    said.append("awaited")
                }
                .node)
        let payload = [SwipeDirection.up.propValue, Point(x: 0, y: -500).propValue]

        XCTAssertTrue(renders.fire(patch.events?["dismissed"] ?? -1, with: payload) { said.append("ended") })
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(said, ["returned"], "one run still awaits")

        lets.yield()
        for _ in 0..<200 {
            guard !said.contains("ended") else { break }
            await Task.yield()
        }
        XCTAssertEqual(said, ["returned", "awaited", "ended"])
    }

    /// AN EVENT NOBODY RUNS FOR ENDS AT ONCE: a gate that lets the event go leaves no run to wait for.
    func testAnEventItsGateLetsGoEndsAtOnce() async throws {
        let renders = Renders()
        var said: [String] = []
        let (waits, lets) = AsyncStream<Void>.makeStream()
        let patch = renders.render(
            Rectangle()
                .onDismissed(policy: .ignoreWhileRunning) { _ in
                    for await _ in waits { break }
                    said.append("first")
                }
                .node)
        let payload = [SwipeDirection.up.propValue, Point(x: 0, y: -500).propValue]
        let event = patch.events?["dismissed"] ?? -1

        renders.fire(event, with: payload)
        XCTAssertTrue(renders.fire(event, with: payload) { said.append("second ended") })
        for _ in 0..<200 {
            guard !said.contains("second ended") else { break }
            await Task.yield()
        }
        XCTAssertEqual(said, ["second ended"], "let go by the gate, with the first still under way")

        lets.yield()
        for _ in 0..<200 {
            guard !said.contains("first") else { break }
            await Task.yield()
        }
        XCTAssertEqual(said, ["second ended", "first"])
    }
}

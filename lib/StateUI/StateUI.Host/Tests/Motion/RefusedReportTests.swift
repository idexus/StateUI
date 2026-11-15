// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A report a refusal takes back publishes nothing of what it took back: the host's run of a source it wrote and put
/// back travels on to its own deadline, its waiter answered as it arrives.
@MainActor
final class RefusedReportTests: XCTestCase {
    func testARefusedReportLeavesTheHostsRunOnItsWay() throws {
        let record = SceneRecord(id: "refused", declaration: 0)
        let kind = KeyName("refused.document")
        record.open(kind, value: AnyHashable(1.0), text: "1")
        record.open(kind, value: AnyHashable(2.0), text: "2")
        let (a, b) = (record.windowValue(record.windows[0], as: Double.self), record.windowValue(record.windows[1], as: Double.self))
        let sum = Binding<Double>.multi(a.projectedValue, b.projectedValue).convert({ $0 + $1 }, back: { _ in (3, 3) })
        let back = try XCTUnwrap(sum.storage.conversion)
        let differ = Differ()
        let mounted = differ.reconcile(nil, with: VStack {
            Slider(a.projectedValue).maximum(100)
            Slider(b.projectedValue).maximum(100)
            Slider(sum).maximum(100)
        }.node).node
        let board = Renderer.shared.board
        board.cycle(now: 0, reducesMotion: false)
        _ = board.dirty()
        a.projectedValue.journey.snap(to: 0)
        let arrival = a.projectedValue.journey.move(to: 1, .eased(.seconds(1), curve: .linear))
        board.cycle(now: 0, reducesMotion: false)
        _ = board.dirty()
        let image = try XCTUnwrap(a.storage.carryAsJourney())
        let binding = HostStateBinding(state: try XCTUnwrap(image.number), mode: .inOut, kind: .property, laneKind: .number)
        let animator = Animator()
        let channels = StateChannels(animator: animator)
        channels.attach(binding.state)
        let initial = try XCTUnwrap(Renderer.shared.hostValue(for: binding))
        _ = channels.presentedValue(for: binding, from: initial, now: 0, reducesMotion: false)
        _ = (channels.takeOutputs(), channels.takeCompletions())
        // A tenth of the way, the host reports where the value stands.
        channels.follow(animator.advance(to: 100))
        for output in channels.takeOutputs() {
            if let report = output.report { _ = Renderer.shared.hostReported(output.journey, updating: report, through: binding) }
        }
        board.cycle(now: 100, reducesMotion: false)
        _ = board.dirty()

        sum.storage.settle(6, asking: false)
        XCTAssertEqual(back.back?(), false, "the report refused: two windows of a kind asked for one value")
        board.cycle(now: 100, reducesMotion: false)
        for change in board.dirty() where change.number == binding.state {
            let carried = StateImage.carried(of: change.bytes, lanes: StateValueLanes.own)
            channels.receive(HostStateChange(state: change.number, changed: change.mask, value: carried), now: 100, reducesMotion: false)
        }
        XCTAssertEqual(channels.takeCompletions().count, 0, "no run cut short")

        channels.follow(animator.advance(to: 1_000))
        XCTAssertEqual(try XCTUnwrap(channels.takeOutputs().last?.journey.value.first), 1, accuracy: 1e-9, "at its own deadline")
        XCTAssertEqual(channels.takeCompletions().map(\.succeeded), [true], "its waiter answered as it arrived")
        withExtendedLifetime((record, mounted, differ, back, arrival)) {}
    }
}

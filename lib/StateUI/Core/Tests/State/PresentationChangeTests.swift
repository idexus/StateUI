// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// A change of the presentation in the core: the writes it runs, the record the next render carries, and the
/// host's two answers reaching whoever waits.
@MainActor
final class PresentationChangeTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
        _ = Renderer.shared.takeChanges()
    }

    /// A change aimed at the panel, and the record a render would carry for it.
    private func made(_ update: () -> Void = {}) throws -> (change: PresentationChange, record: HostPresentationChange) {
        let change = try named("panel", VStack.self).presentationChange(update)
        return (change, try XCTUnwrap(Renderer.shared.takeChanges().first))
    }

    /// AN AIM THAT REACHED NO VIEW THROWS BEFORE THE WRITES: they are not run, and no render carries a change.
    func testAnAimThatReachedNoViewThrowsBeforeTheWrites() {
        var ran = false

        XCTAssertThrowsError(try Aim(VStack.self).presentationChange { ran = true })

        XCTAssertFalse(ran)
        XCTAssertTrue(Renderer.shared.takeChanges().isEmpty)
    }

    /// THE WRITES RUN AT ONCE AND THE NEXT RENDER CARRIES THE CHANGE, ONCE: where its aim stands and two waiters
    /// of its own - and the change asks for that render, whatever its writes ask for.
    func testTheNextRenderCarriesTheChangeOnce() throws {
        var ran = false
        XCTAssertFalse(Renderer.shared.needsRender)

        _ = try named("panel", VStack.self).presentationChange { ran = true }

        XCTAssertTrue(ran, "before the call returns")
        XCTAssertTrue(Renderer.shared.needsRender, "a change with no write a view reads still asks for its render")
        let carried = Renderer.shared.takeChanges()
        XCTAssertEqual(carried.map(\.place), [[.manual("panel")]])
        XCTAssertNotEqual(carried.first?.applied, carried.first?.settled)
        XCTAssertTrue(Renderer.shared.takeChanges().isEmpty, "a render later carries it no more")
    }

    /// THE HOST'S TWO ANSWERS REACH THEIR OWN WAITERS, each once: the application first, the end apart from it -
    /// its reasons each once, in the order they are declared.
    func testTheHostsTwoAnswersReachTheirWaiters() async throws {
        let (change, record) = try made()
        var applied: PresentationApplication?
        var settled: PresentationResult?
        let first = Task { @MainActor in applied = try await change.applied() }
        let second = Task { @MainActor in settled = try await change.settled() }
        await settle()
        XCTAssertNil(applied, "nobody is answered before the host says")
        XCTAssertNil(settled)

        XCTAssertTrue(HostBoundary.answer(record.applied, applied: .applied))
        try await first.value
        XCTAssertEqual(applied, .applied)
        XCTAssertNil(settled, "the end is another answer")

        XCTAssertTrue(HostBoundary.answer(record.settled, settled: .interrupted([.detached, .superseded, .detached])))
        try await second.value
        XCTAssertEqual(settled, .interrupted([.superseded, .detached]))
        XCTAssertFalse(HostBoundary.answer(record.settled, settled: .settled), "answered once")
        let asked = try await change.settled()
        XCTAssertEqual(asked, .interrupted([.superseded, .detached]), "asked after the end, it answers at once")
    }

    /// EVERY RESULT CROSSES AS ITSELF.
    func testEveryResultCrossesAsItself() async throws {
        let results: [PresentationResult] = [.settled, .notPresented, .interrupted([.superseded]), .interrupted([.detached])]
        for result in results {
            let (change, record) = try made()
            HostBoundary.answer(record.applied, applied: .notPresented)
            HostBoundary.answer(record.settled, settled: result)

            let application = try await change.applied()
            let end = try await change.settled()
            XCTAssertEqual(application, .notPresented)
            XCTAssertEqual(end, result)
        }
    }

    /// A HOST THAT WENT SHOWS NOTHING: a waiter it failed, or one the application's end took, hears `notPresented`.
    func testAHostThatWentShowsNothing() async throws {
        let (change, record) = try made()

        HostBoundary.fail(record.applied, reason: "the host is closing")
        change.land(settled: .cancelled)

        let application = try await change.applied()
        let end = try await change.settled()
        XCTAssertEqual(application, .notPresented)
        XCTAssertEqual(end, .notPresented)
    }

    /// A WAITER WHOSE TASK IS CANCELLED STOPS ALONE: the change ends all the same, for whoever else waits.
    func testACancelledWaiterStopsAloneAndTheChangeGoesOn() async throws {
        let (change, record) = try made()
        var cancelledEnded: Result<PresentationResult, any Error>?
        var otherEnded: PresentationResult?
        let cancelled = Task { @MainActor in
            do { cancelledEnded = .success(try await change.settled()) } catch { cancelledEnded = .failure(error) }
        }
        let other = Task { @MainActor in otherEnded = try await change.settled() }
        await settle()

        cancelled.cancel()
        await cancelled.value
        guard case .failure(let error) = cancelledEnded else { return XCTFail("the cancelled waiter heard an end") }
        XCTAssertTrue(error is CancellationError)
        XCTAssertNil(otherEnded, "the other waits on")

        HostBoundary.answer(record.settled, settled: .settled)
        try await other.value
        XCTAssertEqual(otherEnded, .settled)
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A window's VALUE - what a window of a kind for a value is about - on every road a value comes in by: a write, a
// post, a movement, a landing, the host's report. Each lands the same way, retargeting the window, and a value
// another window of the kind is open for is refused the same way: the state, the window and its control stand.

import XCTest
@_spi(Host) @testable import StateUI

private extension WindowKind where Value == Double {
    static let gauge = WindowKind("gauge")
}

private extension WindowKind where Value == String {
    static let label = WindowKind("label")
}

/// A gauge window: its value in a stepper, which the host reports a journey into.
private struct Gauge: View {
    @Binding var reading: Double

    var body: some View { Stepper($reading) }
}

/// A label window: its value in a field, which the host reports a text into.
private struct Label: View {
    @Binding var words: String

    var body: some View { TextField($words) }
}

private struct Meters: Application {
    var body: some Scene {
        WindowGroup { Text("home") }
        WindowGroup(.gauge) { $reading in Gauge(reading: $reading) }
        WindowGroup(.label) { $words in Label(words: $words) }
    }
}

private struct Unexpected: Error {}

@MainActor
final class WindowValueTests: XCTestCase {
    private var renders = Renders()

    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.setApplication(Meters())
        renders = Renders()
        renders.render(tree())
    }

    override func tearDown() async throws {
        OpenScenes.shared.reset()
        Renderer.shared.clearInvalidation()
        _ = drainedActs()
    }

    private func tree() -> Node { OpenScenes.shared.tree(of: Renderer.shared.madeApplication()!) }

    private var application: ApplicationSession { StandardEnvironment.application }

    /// The windows of `kind` open, in the order opened, each with the scene it is in - a serial counts within one.
    private func windows<Value>(_ kind: WindowKind<Value>) -> [(record: SceneRecord, window: OpenedWindow)] {
        OpenScenes.shared.list.flatMap { record in
            record.windows.filter { $0.type?.name == kind.name }.map { (record, $0) }
        }
    }

    /// The values the windows of `kind` are about, and the texts the platform keeps them by.
    private func about<Value>(_ kind: WindowKind<Value>) -> (values: [AnyHashable], texts: [String]) {
        (windows(kind).compactMap(\.window.value), windows(kind).compactMap(\.window.text))
    }

    /// The binding of the window of `kind` opened for `value` - the one its page was handed.
    private func binding<Value: Codable & Hashable>(_ kind: WindowKind<Value>, _ value: Value) throws -> Binding<Value> {
        let (record, window) = try XCTUnwrap(windows(kind).first { $0.window.value == AnyHashable(value) })
        return record.windowValue(window, as: Value.self).projectedValue
    }

    /// The channel the first element of `type` under `patch` is driven on for `key`.
    private func channel(_ type: NodeType, _ key: Prop, in patch: HostPatch) throws -> HostStateBinding {
        let element = try XCTUnwrap(patch.subtree.first { $0.type == type })
        guard case .replace(let driven)? = element.driven else { throw Unexpected() }
        return try XCTUnwrap(driven[key])
    }

    /// Opens two gauge windows, for 1 and 2: the first's binding, and the channel its stepper walks.
    private func gauges() async throws -> (first: Binding<Double>, channel: HostStateBinding) {
        try await application.openWindow(.gauge, value: 1)
        try await application.openWindow(.gauge, value: 2)
        let whole = renders.renderFromScratch(tree())
        return (try binding(.gauge, 1), try channel(.stepper, .value, in: whole))
    }

    /// The host reports the stepper landed at `value`: there, going nowhere, standing still.
    private func report(_ value: Double, through channel: HostStateBinding) throws {
        let standing = try XCTUnwrap(HostBoundary.value(for: channel).flatMap(HostBoundary.journey(from:)))
        let landed = HostJourney(
            value: [value], destination: [value], velocity: [0],
            motion: standing.motion, completion: standing.completion, stopped: standing.stopped)
        XCTAssertTrue(HostBoundary.report(landed, updating: .position, through: channel))
    }

    /// What the next cycle hands the host for `channel`'s state - where its control is put - or nil for nothing.
    private func handed(_ channel: HostStateBinding) -> HostStateValue? {
        HostBoundary.cycle(now: 0, reducesMotion: false).changes.first { $0.state == channel.state }?.value
    }

    /// The host reporting the first gauge's stepper at 2 - the value the second is open for - is refused: the
    /// state, the windows and their texts stand, and the stepper is put back to 1.
    func testAHostReportOfAJourneyIsRefusedWhereAnotherWindowIsOpenForIt() async throws {
        let (first, channel) = try await gauges()
        try report(2, through: channel)
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(first.wrappedValue, 1)
        XCTAssertTrue(hasComplained("is open for the value 2.0 already"))
        XCTAssertEqual(about(.gauge).values, [AnyHashable(1.0), AnyHashable(2.0)])
        XCTAssertEqual(about(.gauge).texts, [try ValueText.write(1.0), try ValueText.write(2.0)])
        guard case .lanes(let lanes)? = handed(channel) else { return XCTFail("the host is handed the value put back") }
        XCTAssertEqual(Array(lanes.prefix(2)), [1, 1], "value and destination, where the window's value stands")
    }

    /// The same report to a value no window is open for lands: the state, the window and its text all say 3.
    func testAHostReportOfAJourneyToAFreeValueRetargetsTheWindow() async throws {
        let (first, channel) = try await gauges()
        try report(3, through: channel)
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(first.wrappedValue, 3)
        XCTAssertEqual(about(.gauge).values, [AnyHashable(3.0), AnyHashable(2.0)])
        XCTAssertEqual(about(.gauge).texts, [try ValueText.write(3.0), try ValueText.write(2.0)])
    }

    /// The host reporting the first label's field typed to "b" - the second's value - is refused, and the field is
    /// put back to "a".
    func testAHostReportOfATextIsRefusedWhereAnotherWindowIsOpenForIt() async throws {
        try await application.openWindow(.label, value: "a")
        try await application.openWindow(.label, value: "b")
        let whole = renders.renderFromScratch(tree())
        let channel = try channel(.textField, .text, in: whole)
        let first = try binding(.label, "a")

        XCTAssertTrue(HostBoundary.report(.string("b"), through: channel))
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(first.wrappedValue, "a")
        XCTAssertEqual(about(.label).values, [AnyHashable("a"), AnyHashable("b")])
        XCTAssertEqual(about(.label).texts, [try ValueText.write("a"), try ValueText.write("b")])
        guard case .string(let put)? = handed(channel) else { return XCTFail("the host is handed the text put back") }
        XCTAssertEqual(put, "a")
    }

    /// A movement of the first gauge's value to 2 is refused before it starts: nothing travels, the windows stand,
    /// and the movement answers that it did not arrive.
    func testAMovementToAValueAnotherWindowIsOpenForIsRefused() async throws {
        let (first, _) = try await gauges()
        let movement = first.journey.move(to: 2, .none)

        XCTAssertEqual(first.wrappedValue, 1)
        XCTAssertEqual(about(.gauge).values, [AnyHashable(1.0), AnyHashable(2.0)])
        let arrived = try await movement.arrived()
        XCTAssertFalse(arrived)
    }

    /// A landing - `snap(to:)` - is a value coming in like any other: at 2 it is refused, at 3 it retargets the
    /// window, the state and the window's record never parting.
    func testALandingIsRefusedOrRetargetsTheWindowAsAWriteDoes() async throws {
        let (first, _) = try await gauges()
        first.journey.snap(to: 2)

        XCTAssertEqual(first.wrappedValue, 1)
        XCTAssertEqual(about(.gauge).values, [AnyHashable(1.0), AnyHashable(2.0)])

        first.journey.snap(to: 3)

        XCTAssertEqual(first.wrappedValue, 3)
        XCTAssertEqual(about(.gauge).values, [AnyHashable(3.0), AnyHashable(2.0)])
        XCTAssertEqual(about(.gauge).texts, [try ValueText.write(3.0), try ValueText.write(2.0)])
    }

    /// A post lands as a write does, in a job of the UI thread's: at 2 refused, at 3 retargeting the window.
    func testAPostIsRefusedOrRetargetsTheWindowAsAWriteDoes() async throws {
        let (first, _) = try await gauges()
        first.post(2)
        _ = await settle()

        XCTAssertEqual(first.wrappedValue, 1)
        XCTAssertEqual(about(.gauge).values, [AnyHashable(1.0), AnyHashable(2.0)])

        first.post(3)
        _ = await settle()

        XCTAssertEqual(first.wrappedValue, 3)
        XCTAssertEqual(about(.gauge).values, [AnyHashable(3.0), AnyHashable(2.0)])
    }
}

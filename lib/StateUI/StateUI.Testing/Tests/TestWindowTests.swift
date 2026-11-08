// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) @testable import StateUITesting
import XCTest

/// A test's window shows a page with no toolkit, finds its views as automation does, and acts on them as the user
/// does - each act's work done before the test reads what it changed.
@MainActor
final class TestWindowTests: XCTestCase {
    func testReadingAMemberTheViewDoesNotWearFails() async throws {
        let window = try await TestWindow(motion: .none) { Text("words").accessibilityIdentifier("words") }

        XCTAssertEqual(try window.element("words").value(TextElementContract.text), "words")
        XCTAssertThrowsError(try window.element("words").value(RangeElementContract.value), "a text holds no slider's value")
        try await window.close()
    }

    func testAClickIsCounted() async throws {
        let window = try await TestWindow(motion: .none) { CounterPage() }
        let button = try window.element("counter.add")
        XCTAssertEqual(try button.value(TextElementContract.text), "Clicked 0 times")

        try await button.perform(.activate)
        try await button.perform(.activate)

        XCTAssertEqual(try button.value(TextElementContract.text), "Clicked 2 times")
    }

    /// Words typed reach the state the field is bound to, and a switch turned reaches its own.
    func testWordsTypedAndASwitchTurnedReachTheirStates() async throws {
        let window = try await TestWindow(motion: .none) { FormPage() }
        let field = try window.element("form.name")
        let lamp = try window.element("form.lamp")

        try await field.perform(.type("Ada"))
        try await lamp.perform(.toggle)

        XCTAssertEqual(try window.element("form.greeting").value(TextElementContract.text), "Hello, Ada - lit")
        XCTAssertEqual(try lamp.value(ToggleElementContract.isOn), true)
    }

    /// A view is found by the aim put on it, as the application aims at it.
    func testAViewIsFoundByItsAim() async throws {
        let page = AimedPage()
        let window = try await TestWindow(motion: .none) { page }
        let field = try window.element(page.name)

        try await field.perform(.type("Grace"))

        XCTAssertEqual(try field.value(TextElementContract.text), "Grace")
    }

    /// The walk every host's suite takes a window through holds with no toolkit too.
    func testTheWalkHoldsWithNoToolkit() {
        XCTAssertEqual(TestWindowWalk.failures(on: CoreDriver()), [])
    }

    /// A view no view is, or one two views are, is a failure naming it - not a guess.
    func testAViewNotThereOrTwiceThereFails() async throws {
        let window = try await TestWindow(motion: .none) { FormPage() }

        XCTAssertThrowsError(try window.element("form.nothing")) { error in
            XCTAssertEqual("\(error)", "no view is the view \"form.nothing\"")
        }
        XCTAssertThrowsError(try window.element("form.twice")) { error in
            XCTAssertEqual("\(error)", "2 views are the view \"form.twice\"")
        }
    }

    /// The window acts as the user can: nothing on a disabled view, no words into a read-only field - each a failure
    /// saying why - and words typed held as the field holds them, in its case and to its bound.
    func testTheWindowActsAsTheUserCan() async throws {
        let window = try await TestWindow(motion: .none) { GuardedPage() }

        do {
            try await window.element("guarded.locked").perform(.activate)
            XCTFail("a disabled button was activated")
        } catch {
            XCTAssertTrue("\(error)".contains("disabled"), "\(error)")
        }
        do {
            try await window.element("guarded.shown").perform(.type("changed"))
            XCTFail("a read-only field took words")
        } catch {
            XCTAssertTrue("\(error)".contains("read-only"), "\(error)")
        }
        try await window.element("guarded.code").perform(.type("ab"))

        XCTAssertEqual(try window.element("guarded.state").value(TextElementContract.text), "0 kept A")
    }

    /// A new window takes the place of the last: a view found in the last is found no more.
    func testANewWindowTakesThePlaceOfTheLast() async throws {
        let last = try await TestWindow(motion: .none) { CounterPage() }
        let button = try last.element("counter.add")
        XCTAssertEqual(try button.value(TextElementContract.text), "Clicked 0 times")

        let next = try await TestWindow(motion: .none) { FormPage() }

        XCTAssertNotNil(try next.element("form.name"))
        XCTAssertThrowsError(try button.value(TextElementContract.text), "the last window closed")
        XCTAssertThrowsError(try last.element("counter.add"))
    }

    /// The page hears it is shown as the window opens, as a host's window tells it, so what it does on appearing is
    /// done before the test reads it.
    func testThePageHearsItIsShownAsTheWindowOpens() async throws {
        let window = try await TestWindow(motion: .none) { AppearingPage() }

        XCTAssertEqual(try window.element("appearing.state").value(TextElementContract.text), "appeared")
    }

    /// An act is done once the work it began is: a handler still awaiting holds `perform`, which returns after the
    /// handler's last write shows - and holds on nothing the page began before the act, which runs on.
    func testAnActWaitsOnTheWorkItBeganAlone() async throws {
        let held = Held()
        let window = try await TestWindow(motion: .none) { WaitingPage(held: held) }
        defer { held.service?.resume() }
        XCTAssertTrue(held.serviceBegan, "the page's service runs on through the window's start")
        let button = try window.element("waiting.go")

        let action = Task { @MainActor in
            try await button.perform(.activate)
            held.returned = true
        }
        for _ in 0..<1000 { if held.entered { break }; await Task.yield() }
        XCTAssertTrue(held.entered)
        for _ in 0..<300 { await Task.yield() }
        XCTAssertFalse(held.returned, "perform waits on the handler it began")
        held.release?.resume()
        held.release = nil
        try await action.value

        XCTAssertTrue(held.returned)
        XCTAssertEqual(try button.value(TextElementContract.text), "done", "its last write shown")
    }

    /// An act waits on its handler wherever the test does it from - a task through a gate too, whose run is not
    /// the act's: the handler the act raised begins runs of its own.
    func testAnActFromATaskThroughAGateWaitsOnItsHandler() async throws {
        let held = Held()
        let window = try await TestWindow(motion: .none) { WaitingPage(held: held) }
        defer { held.service?.resume() }
        let button = try window.element("waiting.go")

        let action = Task(gate: Gate(.runConcurrently)) {
            try await button.perform(.activate)
            held.returned = true
        }
        for _ in 0..<1000 { if held.entered { break }; await Task.yield() }
        XCTAssertTrue(held.entered)
        for _ in 0..<300 { await Task.yield() }
        XCTAssertFalse(held.returned, "perform waits on the handler it began")
        held.release?.resume()
        held.release = nil
        await action.value

        XCTAssertTrue(held.returned)
        XCTAssertEqual(try button.value(TextElementContract.text), "done", "its last write shown")
    }

    /// An act holds on nothing an earlier service begins while the act runs: the service the page began as it
    /// appeared goes on through the act and starts work of its own, which is the service's, not the act's.
    func testAnActHoldsOnNothingAnEarlierServiceBegins() async throws {
        let held = Onward()
        let window = try await TestWindow(motion: .none) { OnwardPage(held: held) }
        defer { held.ownWork?.resume() }
        let button = try window.element("onward.go")

        let action = Task { @MainActor in
            try await button.perform(.activate)
            held.returned = true
        }
        for _ in 0..<1000 { if held.entered { break }; await Task.yield() }
        XCTAssertTrue(held.entered)
        held.service?.resume()
        held.service = nil
        for _ in 0..<1000 { if held.ownWorkBegan { break }; await Task.yield() }
        XCTAssertTrue(held.ownWorkBegan, "the service, let go, began work of its own")
        held.release?.resume()
        held.release = nil
        try await action.value

        XCTAssertTrue(held.returned, "the service's own work holds no act")
    }
}

/// What the page's service and handler hold: the continuations that keep them running, and what they came to.
@MainActor private final class Onward {
    let gate = Gate(.runConcurrently)
    var service: CheckedContinuation<Void, Never>?
    var entered = false
    var release: CheckedContinuation<Void, Never>?
    var ownWorkBegan = false
    var ownWork: CheckedContinuation<Void, Never>?
    var returned = false
}

/// A page whose service, let go, begins work of its own through a gate and waits on it, and whose button's handler
/// waits to be let go.
private struct OnwardPage: View {
    let held: Onward

    var body: some View {
        Button("Go").accessibilityIdentifier("onward.go")
            .onClicked(policy: .runConcurrently) {
                await withCheckedContinuation { held.release = $0; held.entered = true }
            }
            .onAppearing(policy: .runConcurrently) {
                await withCheckedContinuation { held.service = $0 }
                await Task(gate: held.gate) {
                    await withCheckedContinuation { held.ownWork = $0; held.ownWorkBegan = true }
                }.value
            }
    }
}

/// A page that says it appeared.
private struct AppearingPage: View {
    @State private var state = "made"

    var body: some View {
        Text(state).accessibilityIdentifier("appearing.state").onAppearing { state = "appeared" }
    }
}

/// What a page's handlers hold: the continuations that keep them running, and what they came to.
@MainActor private final class Held {
    var serviceBegan = false
    var service: CheckedContinuation<Void, Never>?
    var entered = false
    var release: CheckedContinuation<Void, Never>?
    var returned = false
}

/// A page whose service runs for its life, and whose button's handler waits to be let go.
private struct WaitingPage: View {
    let held: Held
    @State private var label = "go"

    var body: some View {
        Button(label).accessibilityIdentifier("waiting.go")
            .onClicked(policy: .runConcurrently) {
                await withCheckedContinuation { held.release = $0; held.entered = true }
                label = "done"
            }
            .onAppearing(policy: .runConcurrently) {
                held.serviceBegan = true
                await withCheckedContinuation { held.service = $0 }
            }
    }
}

/// A page the user cannot do everything to: a disabled button, a read-only field, a field holding one capital.
private struct GuardedPage: View {
    @State private var clicks = 0
    @State private var shown = "kept"
    @State private var code = ""

    var body: some View {
        VStack {
            Button("Locked").isEnabled(false).accessibilityIdentifier("guarded.locked").onClicked { clicks += 1 }
            TextField($shown).isReadOnly(true).accessibilityIdentifier("guarded.shown")
            TextField($code).textCase(.uppercase).maximumLength(1).accessibilityIdentifier("guarded.code")
            Text("\(clicks) \(shown) \(code)").accessibilityIdentifier("guarded.state")
        }
    }
}

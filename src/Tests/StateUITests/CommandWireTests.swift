// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The command channel's wire format, written down for the other side.
//
// `fixtures/commands/*.bin` are produced here by the REAL typed calls -
// `focus`, a scroll, a dialog - and read by `CommandFixtureTests.cs`, which
// asserts the exact reads `StateUISession.Perform` makes: the view name at 0,
// the length two from the end, the easing last. One fixture per SHAPE rather
// than per method, because the ten ViewExtensions animations share one and
// `testEveryAnimationInTheLibraryIsExercised` already holds each to it.
//
// Beside every `.bin` sits a `.txt` sidecar - WireProbe's rendering of the
// same batch - because a binary fixture is unreadable in a review diff and
// the readability was half the point of committing fixtures at all. The
// bytes are the contract; the sidecar is what a human reads.
//
// The completion id counts down globally and the navigation's request number
// counts up, so a fixture pins both: the batch is DECODED, normalized at the
// value level, and encoded again with the library's own writer - the same
// bytes a run with those numbers would have produced.
//
// Without these, the two sides of the channel were tested only against
// themselves: reordering length and easing on both sides at once kept every
// suite green while every animation ran with a garbage duration.

import StateUIWireProbe
import XCTest
@testable import StateUI

final class CommandWireTests: XCTestCase {
    private typealias Act<Value> = nonisolated(nonsending) () async throws -> Value

    /// Empties the shared queue, so a test starts from nothing - showing the
    /// bytes to the probe either way, so the session mirror hears every
    /// announcement, discarded batches included.
    @discardableResult
    private func drain() -> [UInt8] {
        let bytes = Renderer.shared.takeCommandsWire()
        _ = WireProbe.decode(bytes)
        return bytes
    }

    /// Starts an act and lets it reach its suspension - see CommandTests.
    private func begin<Value>(_ body: sending @escaping Act<Value>) -> Task<Value, Error> {
        let task = Task { @MainThread in try await body() }
        stateUIRunJobs()
        return task
    }

    /// Reports an act as done, so no test leaves a continuation suspended.
    private func finish(_ acts: [WireAct]) async {
        guard let id = acts.compactMap(\.completion).first else { return }

        ReplyBuffer.current = .finished([.bool(true)])
        _ = Renderer.shared.dispatch(id)
        await settle()
    }

    /// One act, drained, checked, and finished. Takes Void so the compiler
    /// does not have to prove an arbitrary result Sendable; an animation call
    /// wraps itself in `_ =`.
    ///
    /// `pinning` normalizes whatever else a fixture cannot carry - the
    /// navigation's request number - AFTER the completion id is pinned to -1.
    private func check(
        _ fixture: String,
        pinning: ((inout [WireAct]) -> Void)? = nil,
        _ body: sending @escaping Act<Void>
    ) async throws {
        drain()
        let task = begin(body)
        let taken = WireProbe.decode(drain())

        var pinned = taken.map { act in
            WireAct(
                name: act.name,
                arguments: act.arguments,
                completion: act.completion.map { _ in -1 })
        }
        pinning?(&pinned)

        try Fixtures.check(
            Wire.encode(
                pinned.map {
                    Command(act: StateUI.Act($0.name), arguments: $0.arguments, completion: $0.completion)
                },
                dictionary: WireDictionary()),
            sidecar: WireProbe.dump(pinned),
            against: "commands/\(fixture)")

        await finish(taken)
        _ = try? await task.value
    }

    /// An act on a control the author never NAMED carries the element identity
    /// as a NUMBER - the other namespace of the same argument, resolved through
    /// `Tracked` where a name goes through `Named`. The box is filled by hand
    /// here because the differ's half is ControlStateTests' business; what this
    /// pins is the wire.
    func testAnActByElementNumberCrossesAsItsFixtureSays() async throws {
        let field = ControlState<Entry>()
        field.box.attach(.auto(7), walk: 1)

        try await check("FocusByNumber") {
            _ = try await field.focus()
        }
    }

    /// The one-button alert: three arguments, so the host knows there is
    /// nothing to answer beyond "it was dismissed".
    func testAnInformingAlertCrossesAsItsFixtureSays() async throws {
        try await check("DisplayAlertOneButton") {
            try await Dialogs.displayAlert("Saved", message: "The draft is safe")
        }
    }

    /// The question form: four arguments, accept before cancel, MAUI's order.
    func testAQuestionAlertCrossesAsItsFixtureSays() async throws {
        try await check("DisplayAlert") {
            _ = try await Dialogs.displayAlert(
                "Delete draft?", message: "This cannot be undone",
                accept: "Delete", cancel: "Keep")
        }
    }

    /// Title, cancel, destruction, then the buttons - MAUI's params order. An
    /// absent caption crosses as the wire's own NOTHING, never as an empty
    /// string: an empty string is a caption someone could have written.
    func testAnActionSheetCrossesAsItsFixtureSays() async throws {
        try await check("DisplayActionSheet") {
            _ = try await Dialogs.displayActionSheet(
                "Share via", cancel: "Cancel", destruction: "Delete",
                buttons: ["Mail", "Message"])
        }
    }

    /// All eight of MAUI's parameters, in MAUI's order. An absent limit crosses
    /// as NOTHING, which the HOST turns into MAUI's own -1 - the sentinel is
    /// MAUI's, at the far end, and never on this wire.
    func testAPromptCrossesAsItsFixtureSays() async throws {
        try await check("DisplayPrompt") {
            _ = try await Dialogs.displayPrompt(
                "Rename", message: "A new name for the draft",
                placeholder: "Name", initialValue: "Draft 1",
                maxLength: 40, keyboard: .text)
        }
    }

    func testFocusingAViewCrossesAsItsFixtureSays() async throws {
        try await check("Focus") {
            _ = try await named("email", Entry.self).focus()
        }
    }

    func testUnfocusingAViewCrossesAsItsFixtureSays() async throws {
        try await check("Unfocus") {
            try await named("email", Entry.self).unfocus()
        }
    }

    /// The one act with no view in it: the host asks the page which of its
    /// views has the focus, because the Swift side cannot know.
    func testClosingTheKeyboardCrossesAsItsFixtureSays() async throws {
        try await check("HideSoftInput") {
            _ = try await SoftInput.hide()
        }
    }

    /// The three parameterless WebView acts share the Focus shape - the view
    /// at 0 and nothing else - and each is pinned by name, so a rename on one
    /// side cannot slip past the other.
    func testGoingBackInAWebViewCrossesAsItsFixtureSays() async throws {
        try await check("WebViewGoBack") {
            try await named("browser", WebView.self).goBack()
        }
    }

    func testGoingForwardInAWebViewCrossesAsItsFixtureSays() async throws {
        try await check("WebViewGoForward") {
            try await named("browser", WebView.self).goForward()
        }
    }

    func testReloadingAWebViewCrossesAsItsFixtureSays() async throws {
        try await check("WebViewReload") {
            try await named("browser", WebView.self).reload()
        }
    }

    /// The one WebView act with a second argument: the script after the view,
    /// and an answer somebody is waiting for.
    func testRunningJavaScriptCrossesAsItsFixtureSays() async throws {
        try await check("EvaluateJavaScript") {
            _ = try await named("browser", WebView.self).evaluateJavaScript("document.title")
        }
    }

    /// A map slides on three numbers after the view: latitude, longitude, and
    /// the radius in METERS - the unit MAUI's Distance is at bottom.
    func testMovingAMapCrossesAsItsFixtureSays() async throws {
        try await check("MoveToRegion") {
            try await named("map", Map.self).moveToRegion(
                latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
        }
    }

    /// A ScrollView slides on two offsets and whether to animate, in MAUI's
    /// order - x before y, ScrollToAsync's own.
    func testScrollingToAnOffsetCrossesAsItsFixtureSays() async throws {
        try await check("ScrollViewScrollTo") {
            try await named("scroller", ScrollView.self).scrollTo(x: 0, y: 400, animated: false)
        }
    }

    func testAskingTheTimeCrossesAsItsFixtureSays() async throws {
        try await check("Now") {
            _ = try? await ClockTime.now()
        }
    }

    func testAskingTheZoneCrossesAsItsFixtureSays() async throws {
        try await check("LocalZone") {
            _ = try? await TimeZoneInfo.local()
        }
    }

    func testAskingForAnOffsetCrossesAsItsFixtureSays() async throws {
        try await check("UtcOffset") {
            _ = try? await TimeZoneInfo.getUtcOffset(
                of: "Europe/Warsaw",
                on: CalendarDate(year: 2026, month: 1, day: 15))
        }
    }

    /// The same act with no day: the absence crosses as NOTHING at argument 1,
    /// keeping its place in the list. An argument list has no field left out -
    /// the count says where every argument is - so absence has to be said out
    /// loud, and this is the fixture that says it.
    func testAskingForAnOffsetWithNoDayCrossesAsItsFixtureSays() async throws {
        try await check("UtcOffsetToday") {
            _ = try? await TimeZoneInfo.getUtcOffset(of: "Europe/Warsaw")
        }
    }

    func testAFailedHandlerCrossesAsItsFixtureSays() throws {
        drain()
        Renderer.shared.report(StateUIError(message: "boom"))

        let acts = WireProbe.decode(drain())
        try Fixtures.check(
            Wire.encode(
                acts.map {
                    Command(act: StateUI.Act($0.name), arguments: $0.arguments, completion: $0.completion)
                },
                dictionary: WireDictionary()),
            sidecar: WireProbe.dump(acts),
            against: "commands/HandlerFailed")
    }
}

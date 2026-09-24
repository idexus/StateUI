// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The act calls a host is handed, written down.
//
// `Fixtures/act-calls/` is produced here by the REAL typed calls - `focus`, a
// dialog, a web view's navigation - and it is what a host's performer is held
// to: the view at 0, then each argument at its own place. One fixture per
// SHAPE rather than per method where acts share one, as the parameterless web
// view acts share the Focus shape.
//
// The completion id counts down across the process, so a fixture pins it: the
// batch is taken typed and its completion normalized to -1.
//
// Without these, each side is tested only against itself: swapping two
// arguments on both sides at once keeps every suite green while a host reads
// each argument as the other.

import XCTest
@_spi(Host) @testable import StateUI

final class ActCallShapeTests: XCTestCase {
    private typealias Act<Value> = nonisolated(nonsending) () async throws -> Value

    /// Empties the shared queue, so a test starts from nothing.
    @discardableResult
    private func drain() -> [HostActCall] {
        drainedActs()
    }

    /// Starts an act and lets it reach its suspension - see ActCallTests.
    @MainActor
    private static func begin<Value>(_ body: sending @escaping Act<Value>) -> Task<Value, Error> {
        Task.immediate { @MainActor in try await body() }
    }

    /// Reports an act as done, so no test leaves a continuation suspended.
    private func finish(_ acts: [HostActCall]) async {
        guard let id = acts.compactMap(\.completion).first else { return }

        StateUIHost.reply(id, with: [.bool(true)])
        await settle()
    }

    /// One act, drained, checked, and finished. Takes Void so the compiler
    /// does not have to prove an arbitrary result Sendable; an animation call
    /// wraps itself in `_ =`.
    private func check(_ fixture: String, _ body: sending @escaping Act<Void>) async throws {
        drain()
        let task = await Self.begin(body)
        let taken = drain()

        let pinned = taken.map { act in
            HostActCall(ActCall(
                act: act.act, arguments: act.arguments, completion: act.completion.map { _ in -1 }))
        }

        try Fixtures.check(pinned, against: "act-calls/\(fixture)")

        await finish(taken)
        _ = try? await task.value
    }

    /// An act on a control the author never NAMED carries the element identity
    /// as a NUMBER - the other namespace of the same argument, resolved through
    /// `Tracked` where a name goes through `Named`. The box is filled by hand
    /// here because the differ's half is AimTests' business; what this
    /// pins is the act.
    func testAnActByElementNumberCrossesAsItsFixtureSays() async throws {
        let field = Aim(TextField.self)
        field.box.attach(.auto(7), walk: 1)

        try await check("FocusByNumber") {
            _ = try await field.focus()
        }
    }

    /// The alert: three arguments, and nothing to answer beyond "it was
    /// dismissed".
    func testAnAlertCrossesAsItsFixtureSays() async throws {
        try await check("Alert") {
            try await Dialogs.alert("Saved", message: "The draft is safe")
        }
    }

    /// The confirmation: four arguments, accept before cancel.
    func testAConfirmationCrossesAsItsFixtureSays() async throws {
        try await check("Confirm") {
            _ = try await Dialogs.confirm(
                "Delete draft?", message: "This cannot be undone",
                accept: "Delete", cancel: "Keep")
        }
    }

    /// Title, cancel, destruction, then the buttons as ONE argument - the list
    /// of their captions, an argument being one value. An absent caption
    /// crosses as NOTHING, never as an empty string: an empty string is a
    /// caption someone could have written.
    func testAChoiceOfActionsCrossesAsItsFixtureSays() async throws {
        try await check("ChooseAction") {
            _ = try await Dialogs.chooseAction(
                "Share via", cancel: "Cancel", destruction: "Delete",
                buttons: ["Mail", "Message"])
        }
    }

    /// All eight parameters, in their order. An absent limit crosses as
    /// NOTHING, which the HOST turns into whatever its toolkit means by "no
    /// limit" - a toolkit's sentinel stays in the host and never crosses.
    func testAPromptCrossesAsItsFixtureSays() async throws {
        try await check("Prompt") {
            _ = try await Dialogs.prompt(
                "Rename", message: "A new name for the draft",
                placeholder: "Name", initialValue: "Draft 1",
                maximumLength: 40, inputPurpose: .text)
        }
    }

    func testFocusingAViewCrossesAsItsFixtureSays() async throws {
        try await check("Focus") {
            _ = try await named("email", TextField.self).focus()
        }
    }

    func testUnfocusingAViewCrossesAsItsFixtureSays() async throws {
        try await check("Unfocus") {
            try await named("email", TextField.self).unfocus()
        }
    }

    /// The one act with no view in it: the host asks the page which of its
    /// views has the focus, because the Swift side cannot know.
    func testClosingTheKeyboardCrossesAsItsFixtureSays() async throws {
        try await check("HideOnScreenKeyboard") {
            _ = try await OnScreenKeyboard.hide()
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
    /// the radius in METERS.
    func testMovingAMapCrossesAsItsFixtureSays() async throws {
        try await check("MoveToRegion") {
            try await named("map", Map.self).moveToRegion(
                latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
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
            _ = try? await TimeZoneInfo.utcOffset(
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
            _ = try? await TimeZoneInfo.utcOffset(of: "Europe/Warsaw")
        }
    }

    func testAFailedHandlerCrossesAsItsFixtureSays() throws {
        drain()
        Renderer.shared.report(StateUIError(message: "boom"))

        try Fixtures.check(drain(), against: "act-calls/HandlerFailed")
    }

    /// What the screen reader is to say, and a handler waiting until it is
    /// said.
    func testAnAnnouncementCrossesAsItsFixtureSays() async throws {
        try await check("Announce") {
            try await ScreenReader.announce("5 results")
        }
    }

    /// A kept value on its way to the store, as the renderer queues it at a
    /// take: the key as a NAME, the value as it is, and nobody waiting.
    func testAKeptValueCrossesAsItsFixtureSays() throws {
        drain()
        PersistentStore.shared.record(PersistentKey("com.example.theme", of: String.self), .string("dusk"))

        try Fixtures.check(drain(), against: "act-calls/PersistValue")
    }

    /// A scene's kept value on its way to the platform's record of that scene:
    /// the scene and the key as NAMES, then the value, and nobody waiting -
    /// the act `Scenes.takeSaves` queues, which SceneTests reads off a live
    /// scene.
    func testASceneValueCrossesAsItsFixtureSays() throws {
        let call = ActCall(ApplicationContract.persistSceneValue, Name("2"), Name("shade"), PropValue.string("dusk"))

        try Fixtures.check([HostActCall(call)], against: "act-calls/PersistSceneValue")
    }

    /// EVERY ACT OF EVERY CONTRACT IS WRITTEN DOWN: a fixture here names it, so
    /// a host's reader of the channel is held to its arguments. An act member
    /// with none is one a host could read wrongly with every suite green.
    func testEveryActOfEveryContractIsWrittenDown() throws {
        let folder = Fixtures.directory.appendingPathComponent("act-calls")
        var written: Set<String> = []

        for file in try FileManager.default.contentsOfDirectory(atPath: folder.path) where file.hasSuffix(".txt") {
            let sidecar = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)

            if let act = sidecar.split(separator: "\n").first?.split(separator: " ").first {
                written.insert(String(act))
            }
        }

        let acts = LibraryContracts.all.flatMap { contract in
            contract.members.filter { ($0 as? any DeclaredMember)?.facts.kind == .act }.map { $0.name }
        }

        XCTAssertGreaterThan(acts.count, 15, "the contracts declare almost no acts")
        XCTAssertEqual(Set(acts).subtracting(written).sorted(), [], "an act no fixture writes down")
    }
}

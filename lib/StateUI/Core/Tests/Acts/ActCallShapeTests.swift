// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The act calls a host is handed, each by the REAL typed call - `focus`, a
// dialog, a web view's navigation - and what a host's performer is held to:
// the act's name, the view at 0, then each argument at its own place, and
// whether a caller waits for the answer.
//
// Without these, each side is tested only against itself: swapping two
// arguments on both sides at once keeps every suite green while a host reads
// each argument as the other.

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class ActCallShapeTests: XCTestCase {
    private typealias Act<Value> = @MainActor () async throws -> Value

    /// Empties the shared queue, so a test starts from nothing.
    @discardableResult
    private func drain() -> [HostActCall] {
        drainedActs()
    }

    /// Starts an act and lets it reach its suspension - see ActCallTests.
    @MainActor
    private static func begin<Value: Sendable>(_ body: @escaping Act<Value>) -> Task<Value, Error> {
        Task.immediate { @MainActor in try await body() }
    }

    /// Reports an act as done, so no test leaves a continuation suspended.
    private func finish(_ acts: [HostActCall]) async {
        guard let id = acts.compactMap(\.completion).first else { return }

        HostBoundary.reply(id, with: [.bool(true)])
        await settle()
    }

    /// One act a caller waits for, made by `body`, taken, checked and
    /// finished. Takes Void so the compiler does not have to prove an
    /// arbitrary result Sendable; a call with a result wraps itself in `_ =`.
    private func check(
        _ act: StateUI.Act,
        _ arguments: [PropValue],
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: sending @escaping Act<Void>
    ) async throws {
        drain()
        let task = Self.begin(body)
        let batch = drain()

        taken(batch, act, arguments, awaited: true, file: file, line: line)

        await finish(batch)
        _ = try? await task.value
    }

    /// A batch holding one act by `act`'s name, its arguments in their places,
    /// with a completion id exactly when a caller waits for it.
    private func taken(
        _ batch: [HostActCall],
        _ act: StateUI.Act,
        _ arguments: [PropValue],
        awaited: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(batch.map(\.name), [act.name], file: file, line: line)
        XCTAssertEqual(batch.first?.arguments, arguments, file: file, line: line)
        XCTAssertEqual(batch.first?.completion != nil, awaited, "whether a caller waits", file: file, line: line)
    }

    /// An act on a control carries where the control stands - the keys from the root down, a NUMBER for an element
    /// the author never named, `ElementID.auto`, a name's text for `.manual` - as its first argument. The box is
    /// filled by hand here because the differ's half is AimTests' business; what this pins is the act.
    func testAnActByElementNumberCrossesWithItsArgumentsInPlace() async throws {
        let field = Aim(TextField.self)
        field.box.attach([.manual("window"), .auto(7)], walk: 1)

        try await check("focus", [.values([.string("window"), .number(7)])]) {
            _ = try await field.focus()
        }
    }

    /// The alert: the window, three arguments, and nothing to answer beyond
    /// "it was dismissed".
    func testAnAlertCrossesWithItsArgumentsInPlace() async throws {
        try await check("alert", Self.usersWindow + [.string("Saved"), .string("The draft is safe"), .string("OK")]) {
            try await WindowSession().alert("Saved", message: "The draft is safe")
        }
    }

    /// The confirmation: the window, four arguments, accept before cancel.
    func testAConfirmationCrossesWithItsArgumentsInPlace() async throws {
        try await check("confirm", Self.usersWindow + [
            .string("Delete draft?"), .string("This cannot be undone"), .string("Delete"), .string("Keep"),
        ]) {
            _ = try await WindowSession().confirm(
                "Delete draft?", message: "This cannot be undone",
                accept: "Delete", cancel: "Keep")
        }
    }

    /// The window, the title, the actions' captions as ONE argument - an
    /// argument being one value - the place of the dangerous one, and the
    /// cancel's caption, the system's word where none is given. No dangerous
    /// action crosses as NOTHING, never as a place no action stands at.
    func testAChoiceOfActionsCrossesWithItsArgumentsInPlace() async throws {
        try await check("chooseAction", Self.usersWindow + [
            .string("Share via"), .strings(["Mail", "Message", "Delete"]), .number(2), .string("Back"),
        ]) {
            _ = try await WindowSession().chooseAction(
                "Share via", among: ["Mail", "Message", "Delete"], destructive: "Delete", cancel: "Back")
        }
        try await check("chooseAction", Self.usersWindow + [
            .string("Share via"), .strings(["mail"]), .nothing, .string("Cancel"),
        ]) {
            enum Share: CaseIterable { case mail }
            _ = try await WindowSession().chooseAction("Share via", among: Share.allCases)
        }
    }

    /// The window, then all eight parameters, in their order. An absent limit crosses as
    /// NOTHING, which the HOST turns into whatever its toolkit means by "no
    /// limit" - a toolkit's sentinel stays in the host and never crosses.
    func testAPromptCrossesWithItsArgumentsInPlace() async throws {
        try await check("prompt", Self.usersWindow + [
            .string("Rename"), .string("A new name for the draft"), .string("OK"), .string("Cancel"),
            .string("Name"), .number(40), InputPurpose.text.propValue, .string("Draft 1"),
        ]) {
            _ = try await WindowSession().prompt(
                "Rename", message: "A new name for the draft",
                placeholder: "Name", initialValue: "Draft 1",
                maximumLength: 40, inputPurpose: .text)
        }
    }

    /// The captions a dialog says by itself speak the system's language, as the platform's own buttons do - every
    /// question's buttons alike, its sentence empty where none is given.
    func testADialogsOwnCaptionsSpeakTheSystemsLanguage() async throws {
        HostBoundary.setLocaleInfo(HostLocaleInfo(
            language: "pl-PL", timeZone: "Europe/Warsaw", uses24HourClock: true,
            firstDayOfWeek: .monday, isMetric: true, writingDirection: .leftToRight))

        try await check("prompt", Self.usersWindow + [
            .string("Rename"), .string(""), .string("OK"), .string("Anuluj"), .nothing, .nothing,
            InputPurpose.automatic.propValue, .string(""),
        ]) {
            _ = try await WindowSession().prompt("Rename")
        }
        try await check("alert", Self.usersWindow + [.string("Zapisano"), .string("Szkic jest bezpieczny"), .string("OK")]) {
            try await WindowSession().alert("Zapisano", message: "Szkic jest bezpieczny")
        }
        try await check("alert", Self.usersWindow + [.string("Zapisano"), .string(""), .string("OK")]) {
            try await WindowSession().alert("Zapisano")
        }
        try await check("confirm", Self.usersWindow + [
            .string("Usunąć szkic?"), .string(""), .string("OK"), .string("Anuluj"),
        ]) {
            _ = try await WindowSession().confirm("Usunąć szkic?")
        }

        HostBoundary.setLocaleInfo(HostLocaleInfo(
            language: nil, timeZone: nil, uses24HourClock: false, firstDayOfWeek: .sunday,
            isMetric: true, writingDirection: .leftToRight))
    }

    func testFocusingAViewCrossesWithItsArgumentsInPlace() async throws {
        try await check("focus", [.values([.string("email")])]) {
            _ = try await named("email", TextField.self).focus()
        }
    }

    func testUnfocusingAViewCrossesWithItsArgumentsInPlace() async throws {
        try await check("unfocus", [.values([.string("email")])]) {
            try await named("email", TextField.self).unfocus()
        }
    }

    /// An act with no view in it, only its window: the host asks the window
    /// which of its views has the focus, because the Swift side cannot know.
    func testClosingTheKeyboardCrossesWithItsArgumentsInPlace() async throws {
        try await check("hideOnScreenKeyboard", Self.usersWindow) {
            _ = try await WindowSession().hideOnScreenKeyboard()
        }
    }

    /// The address a window's act opens with where its session stands in no scene: the window the user is in.
    private static let usersWindow: [PropValue] = [.name(""), .name("")]

    /// The three parameterless WebView acts share the Focus shape - the view
    /// at 0 and nothing else - and each is pinned by name, so a rename on one
    /// side cannot slip past the other.
    func testGoingBackInAWebViewCrossesWithItsArgumentsInPlace() async throws {
        try await check("goBack", [.values([.string("browser")])]) {
            try await named("browser", WebView.self).goBack()
        }
    }

    func testGoingForwardInAWebViewCrossesWithItsArgumentsInPlace() async throws {
        try await check("goForward", [.values([.string("browser")])]) {
            try await named("browser", WebView.self).goForward()
        }
    }

    func testReloadingAWebViewCrossesWithItsArgumentsInPlace() async throws {
        try await check("reload", [.values([.string("browser")])]) {
            try await named("browser", WebView.self).reload()
        }
    }

    /// The one WebView act with a second argument: the script after the view,
    /// and an answer somebody is waiting for.
    func testRunningJavaScriptCrossesWithItsArgumentsInPlace() async throws {
        try await check("evaluateJavaScript", [.values([.string("browser")]), .string("document.title")]) {
            _ = try await named("browser", WebView.self).evaluateJavaScript("document.title")
        }
    }

    /// A list scrolls to an item's identity and says where it stands, after the view.
    func testScrollingAListCrossesWithItsArgumentsInPlace() async throws {
        let list = Aim(ItemsView<Int>.self)
        let renders = Renders()
        let patch = renders.render(ItemsView(0..<1_000) { Text("\($0)") }.aim(list).id("list").node)
        let entries = try XCTUnwrap(patch.props[.items].flatMap(ItemsEntries.init(propValue:)))
        drain()
        try await check("scrollTo", [.values([.string("list")]), .string(entries.sections[0].items[500]),
                                     .enumeration(ScrollAnchor.start.rawValue)]) {
            try await list.scroll(to: 500, anchor: .start)
        }
        withExtendedLifetime(renders) {}
    }

    /// A list of sections scrolls to an item by the identity its own source wrote for it, whatever section holds it.
    func testScrollingASectionedListFindsItsItem() async throws {
        let list = Aim(ItemsView<String>.self)
        let fruit = Section(["Apple", "Pear"]) { Text($0) }.id("Fruit")
        let renders = Renders()
        renders.render(stack([ItemsView(sections: [fruit]).aim(list).node], id: "root"))
        drain()

        let task = Self.begin { try await list.scroll(to: "Pear") }
        let batch = drain()

        XCTAssertEqual(batch.first?.arguments.dropFirst().first, .string("Pear"))

        await finish(batch)
        _ = try? await task.value
        withExtendedLifetime(renders) {}
    }

    /// A map slides on its region after the view: one run of three numbers - latitude, longitude, and the radius in
    /// METERS.
    func testMovingAMapCrossesWithItsArgumentsInPlace() async throws {
        try await check("moveToRegion", [.values([.string("map")]), .numbers([52.2297, 21.0122, 3000])]) {
            try await named("map", Map.self).show(
                MapRegion(center: Location(latitude: 52.2297, longitude: 21.0122), radiusMeters: 3000))
        }
    }

    func testAskingTheTimeCrossesWithItsArgumentsInPlace() async throws {
        try await check("currentTime", []) {
            _ = try? await StandardEnvironment.application.clock.now()
        }
    }

    func testAskingTheDayCrossesAsTheTimeDoes() async throws {
        try await check("currentTime", []) {
            _ = try? await StandardEnvironment.application.clock.today()
        }
    }

    /// A time the host answers with a number that is no whole one - not a number, endless - is an unreadable answer,
    /// thrown, and never stops the application; a whole number written as a fraction reads as the nearest.
    func testATimeTheHostCannotSayIsThrownNotTrapped() async throws {
        drain()
        let task = Self.begin { try await StandardEnvironment.application.clock.now() }
        let call = try XCTUnwrap(drain().first?.completion)
        HostBoundary.reply(call, with: [.numbers([2026, 11, 9, .nan, 30, .infinity, 0])])
        await settle()

        do {
            _ = try await task.value
            XCTFail("a time of no numbers was read")
        } catch let error as StateUIError {
            guard case .unreadableAnswer = error else { return XCTFail("\(error)") }
        }

        let read = Self.begin { try await StandardEnvironment.application.clock.now() }
        let answered = try XCTUnwrap(drain().first?.completion)
        HostBoundary.reply(answered, with: [.numbers([2026, 11, 9, 13.9999999, 30, 15, 250])])
        await settle()
        let time = try await read.value
        XCTAssertEqual(time, ClockTime(hour: 14, minute: 30, second: 15, millisecond: 250))
    }

    func testAskingForAnOffsetCrossesWithItsArgumentsInPlace() async throws {
        try await check("utcOffset", [.string("Europe/Warsaw"), .numbers([2026, 1, 15])]) {
            _ = try? await StandardEnvironment.application.clock.utcOffset(
                of: "Europe/Warsaw",
                on: CalendarDate(year: 2026, month: 1, day: 15))
        }
    }

    /// The same act with no day: the absence crosses as NOTHING at argument 1,
    /// keeping its place in the list. An argument list has no field left out -
    /// the count says where every argument is - so absence has to be said out
    /// loud, and this is the test that says it.
    func testAskingForAnOffsetWithNoDayCrossesWithItsArgumentsInPlace() async throws {
        try await check("utcOffset", [.string("Europe/Warsaw"), .nothing]) {
            _ = try? await StandardEnvironment.application.clock.utcOffset(of: "Europe/Warsaw")
        }
    }

    /// The theme the application holds, as its session sends it - a member of
    /// a closed vocabulary, nobody waiting - and the system's again, once.
    func testTheApplicationsThemeCrossesWithItsArgumentsInPlace() throws {
        drain()
        let application = ApplicationSession()
        application.colorScheme = .dark
        taken(drain(), "useColorScheme", [.enumeration(ColorScheme.dark.rawValue)], awaited: false)

        application.colorScheme = .dark
        XCTAssertTrue(drain().isEmpty, "the theme it holds already is sent no more")
        application.colorScheme = nil
        taken(drain(), "useColorScheme", [.nothing], awaited: false)

        // The theme is a state: written through its binding - a control's, a picker's - it crosses the same way.
        application.$colorScheme.wrappedValue = .light
        taken(drain(), "useColorScheme", [.enumeration(ColorScheme.light.rawValue)], awaited: false)
    }

    /// A new application starts where the platform stands: the theme and the accent the one before it asked of the
    /// host go with that one - its session holds neither, the host is told to follow the platform again, and the
    /// new one asking the same is heard.
    func testANewApplicationTakesBackWhatTheOneBeforeAsked() throws {
        drain()
        let application = StandardEnvironment.application
        application.colorScheme = .dark
        application.accentColor = .firebrick
        drain()

        Renderer.shared.setApplication(Asking())
        defer { OpenScenes.shared.reset() }

        XCTAssertNil(application.colorScheme, "the theme the one before asked")
        XCTAssertNil(application.accentColor, "the accent the one before asked")
        let told = drain()
        XCTAssertEqual(told.map(\.name).sorted(), ["Application.useAccentColor", "Application.useColorScheme"])
        XCTAssertEqual(told.map(\.arguments), [[.nothing], [.nothing]], "the platform's again")

        application.colorScheme = .dark
        taken(drain(), "useColorScheme", [.enumeration(ColorScheme.dark.rawValue)], awaited: false)
        application.colorScheme = nil
        drain()
    }

    /// The accent the application holds crosses as one color - a pair's half in force, and the other half as the
    /// theme turns - and none once it gives the platform's back.
    func testTheApplicationsAccentCrossesAsTheHalfInForce() throws {
        drain()
        HostBoundary.setColorScheme(.light)
        let application = StandardEnvironment.application
        defer {
            application.accentColor = nil
            HostBoundary.setColorScheme(.light)
            drain()
        }
        application.accentColor = Color(light: .firebrick, dark: .steelBlue)
        taken(drain(), "useAccentColor", [Color.firebrick.propValue], awaited: false)

        HostBoundary.setColorScheme(.dark)
        taken(drain(), "useAccentColor", [Color.steelBlue.propValue], awaited: false)

        application.accentColor = .firebrick
        taken(drain(), "useAccentColor", [Color.firebrick.propValue], awaited: false)
        HostBoundary.setColorScheme(.light)
        XCTAssertTrue(drain().isEmpty, "an accent of one color is not sent again as the theme turns")

        application.accentColor = nil
        taken(drain(), "useAccentColor", [.nothing], awaited: false)

        // The accent is a state: written through its binding - a color picker's - it crosses the same way.
        application.$accentColor.wrappedValue = .steelBlue
        taken(drain(), "useAccentColor", [Color.steelBlue.propValue], awaited: false)
    }

    func testAFailedHandlerCrossesWithItsArgumentsInPlace() throws {
        drain()
        Renderer.shared.report(StateUIError.notPerformed(act: "export", reason: "boom"))

        taken(drain(), "handlerFailed", [.string("boom")], awaited: false)
    }

    /// What the screen reader is to say, and a handler waiting until it is
    /// said.
    func testAnAnnouncementCrossesWithItsArgumentsInPlace() async throws {
        try await check("announce", [.string("5 results")]) {
            try await StandardEnvironment.application.announce("5 results")
        }
    }

    /// Words for the clipboard, and a handler waiting until they are on it.
    func testWordsForTheClipboardCrossWithTheirArgumentsInPlace() async throws {
        try await check("writeClipboard", [.string("Copied")]) {
            try await StandardEnvironment.application.clipboard.write("Copied")
        }
    }

    /// The clipboard read, asked with no arguments, a handler waiting for its words.
    func testReadingTheClipboardCrossesWithItsArgumentsInPlace() async throws {
        try await check("readClipboard", []) {
            _ = try? await StandardEnvironment.application.clipboard.read()
        }
    }

    /// A kept value on its way to the store, as the renderer queues it at a
    /// take: the key as a NAME, the value as it is, and nobody waiting.
    func testAKeptValueCrossesWithItsArgumentsInPlace() throws {
        drain()
        PersistentStore.shared.record(PersistentKey<String>("com.example.theme"), .string("dusk"))

        taken(drain(), "persistValue", [.name("com.example.theme"), .string("dusk")], awaited: false)
    }

    /// The window, the kinds of file as ONE argument - each its caption and its
    /// extensions, bare - then whether the dialog takes several: false for one,
    /// true for several.
    func testAFileToOpenCrossesWithItsArgumentsInPlace() async throws {
        let page: PropValue = .values([.string("HTML page"), .strings(["html", "htm"])])
        try await check("openFiles", Self.usersWindow + [.values([page]), .bool(false)]) {
            _ = try await WindowSession().openFile(types: [FileType("HTML page", extensions: [".html", "*.HTM"])])
        }
        try await check("openFiles", Self.usersWindow + [.values([]), .bool(true)]) {
            _ = try await WindowSession().openFiles()
        }
    }

    /// The window, the contents, as ONE run of bytes, then the name it suggests
    /// as written, then the kinds.
    func testAFileToSaveCrossesWithItsArgumentsInPlace() async throws {
        try await check("saveFile", Self.usersWindow + [
            .bytes([60, 112, 62]), .string("Report"), .values([.values([.string("Page"), .strings(["html"])])]),
        ]) {
            _ = try await WindowSession().saveFile(Array("<p>".utf8), name: "Report", types: [FileType("Page", extensions: ["html"])])
        }
    }

    /// The window, then the words and the link - absent ones as nothing, in place.
    func testWhatIsSharedCrossesWithItsArgumentsInPlace() async throws {
        try await check("share", Self.usersWindow + [.string("Notes"), .string("https://www.swift.org")]) {
            _ = try await WindowSession().share(text: "Notes", address: "https://www.swift.org")
        }
        try await check("share", Self.usersWindow + [.nothing, .string("https://www.swift.org")]) {
            _ = try await WindowSession().share(address: "https://www.swift.org")
        }
    }

    /// A file read or launched crosses as where it stands, then its name; a read then says the most bytes it
    /// takes - nothing for the whole file, none below nought.
    func testAChosenFileCrossesAsWhereItStandsAndItsName() async throws {
        let file = ChosenFile(address: "C:\\Reports\\Report.html", name: "Report.html")
        let crossed: PropValue = .strings(["C:\\Reports\\Report.html", "Report.html"])
        try await check("readFile", [crossed, .nothing]) { _ = try await file.read() }
        try await check("readFile", [crossed, .number(1025)]) { _ = try await file.read(atMost: 1025) }
        try await check("readFile", [crossed, .number(0)]) { _ = try await file.read(atMost: -5) }
        try await check("launchFile", [crossed]) { _ = try await file.launch() }
    }

    /// A request crosses as its address, its method's name, its headers as names and values in turn - sorted by
    /// name, so the same request crosses the same way every time - and its body as bytes.
    func testARequestCrossesWithItsArgumentsInPlace() async throws {
        let request = HTTPRequest(
            "https://example.com/parcels", method: .post, headers: ["X-Kept": "2", "Accept": "json"], body: [1, 2])
        try await check("sendRequest", [
            .string("https://example.com/parcels"), .name("POST"), .strings(["Accept", "json", "X-Kept", "2"]),
            .bytes([1, 2]),
        ]) { _ = try await StandardEnvironment.application.send(request) }
    }

    func testCustomRequestMethodsCrossWithTheirCasePreserved() async throws {
        for name in ["ReadRecord", "READRECORD", "readRecord"] {
            let request = HTTPRequest("https://example.com/parcels", method: HTTPMethod(name))
            try await check("sendRequest", [
                .string("https://example.com/parcels"), .name(name), .strings([]), .bytes([]),
            ]) { _ = try await StandardEnvironment.application.send(request) }
        }
    }

    /// The server's answer comes back as its status, its headers - by name in any case, one said twice holding both
    /// values - and its body.
    func testAServersAnswerComesBackAsItWasSaid() async throws {
        drain()
        let task = Self.begin { try await StandardEnvironment.application.send(HTTPRequest("https://example.com")) }
        let call = try XCTUnwrap(drain().first?.completion)

        HostBoundary.reply(call, with: [
            .number(404), .strings(["content-type", "text/plain", "vary", "Accept", "vary", "Accept-Encoding"]),
            .bytes(Array("Not here".utf8)),
        ])
        await settle()
        let response = try await task.value

        XCTAssertEqual(response.status, 404, "a status is an answer")
        XCTAssertEqual(response.header("Content-Type"), "text/plain")
        XCTAssertEqual(response.header("Vary"), "Accept, Accept-Encoding")
        XCTAssertEqual(response.text, "Not here")
    }

    /// A caller whose run is cancelled stops waiting at once - it hears its cancellation, and an answer coming later
    /// reaches no one - and the host is told to stop the call, nobody waiting for that.
    func testACallEndsWithItsRun() async throws {
        drain()
        let task = Self.begin { _ = try await StandardEnvironment.application.send(HTTPRequest("https://example.com")) }
        let id = try XCTUnwrap(drain().first?.completion)

        task.cancel()
        await settle()
        let stopping = drain()
        let stillWaited = Renderer.shared.waiting.contains(id)
        if stillWaited {
            HostBoundary.reply(id, with: [.number(200), .strings([]), .bytes([])])
            await settle()
        }

        XCTAssertFalse(stillWaited, "no caller waits any more")
        taken(stopping, "cancelCall", [.number(Double(id))], awaited: false)
        do {
            try await task.value
            XCTFail("the call answered")
        } catch {
            XCTAssertTrue(error is CancellationError, "the caller hears its cancellation, not \(error)")
        }
        XCTAssertFalse(HostBoundary.reply(id, with: [.number(200)]), "a late answer reaches no one")
    }

    /// An address launched crosses as written.
    func testALinkCrossesAsWritten() async throws {
        try await check("launchAddress", [.string("https://www.swift.org")]) {
            _ = try await StandardEnvironment.application.launch("https://www.swift.org")
        }
    }

    /// A scene's kept value on its way to the platform's record of that scene:
    /// the scene and the key as NAMES, then the value, and nobody waiting -
    /// the act `OpenScenes.takeSaves` queues, which SceneTests reads off a live
    /// scene.
    func testASceneValueCrossesWithItsArgumentsInPlace() throws {
        let call = ActCall(ApplicationContract.persistSceneValue, Name("2"), Name("shade"), PropValue.string("dusk"))

        taken([HostActCall(call)], "persistSceneValue", [.name("2"), .name("shade"), .string("dusk")], awaited: false)
    }

    /// EVERY ACT OF EVERY CONTRACT IS CHECKED HERE: a test of this file names
    /// it, so a host's performer is held to its arguments. An act member with
    /// none is one a host could read wrongly with every suite green. Read out
    /// of this file's own `check` and `taken` calls.
    func testEveryActOfEveryContractIsCheckedHere() throws {
        let source = try XCTUnwrap(SourceTree.testSources().first { $0.path.hasSuffix("/ActCallShapeTests.swift") }?.text)
        let named = try NSRegularExpression(pattern: #"(?:check|taken)\((?:[^"\n]*?, )?"([A-Za-z]+)""#)
        let checked = Set(
            named.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap { match in
                Range(match.range(at: 1), in: source).map { String(source[$0]) }
            })

        let acts = LibraryContracts.all.flatMap { contract in
            contract.members.filter { ($0 as? any DeclaredMember)?.facts.kind == .act }.map { $0.name }
        }

        XCTAssertGreaterThan(acts.count, 15, "the contracts declare almost no acts")
        XCTAssertEqual(Set(acts).subtracting(checked).sorted(), [], "an act no test here checks")
    }
}

/// An application of one empty page: what a registration after another stands for.
private struct Asking: Application {
    var body: some Scene { WindowGroup { Text("") } }
}

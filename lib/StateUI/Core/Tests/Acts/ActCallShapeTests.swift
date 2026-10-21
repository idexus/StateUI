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
        _ act: String,
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
        _ act: String,
        _ arguments: [PropValue],
        awaited: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(batch.map(\.name), [act], file: file, line: line)
        XCTAssertEqual(batch.first?.arguments, arguments, file: file, line: line)
        XCTAssertEqual(batch.first?.completion != nil, awaited, "whether a caller waits", file: file, line: line)
    }

    /// An act on a control the author never NAMED carries the element identity
    /// as a NUMBER - `ElementID.auto`, the other namespace of the same argument
    /// beside a name's `.manual`. The box is filled by hand
    /// here because the differ's half is AimTests' business; what this
    /// pins is the act.
    func testAnActByElementNumberCrossesWithItsArgumentsInPlace() async throws {
        let field = Aim(TextField.self)
        field.box.attach(.auto(7), walk: 1)

        try await check("focus", [.number(7)]) {
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

    /// The captions a dialog says by itself speak the system's language, as the platform's own buttons do.
    func testADialogsOwnCaptionsSpeakTheSystemsLanguage() async throws {
        HostBoundary.setLocaleInfo(HostLocaleInfo(
            language: "pl", region: "PL", name: "pl-PL", timeZone: "Europe/Warsaw", uses24HourClock: true,
            firstDayOfWeek: .monday, isMetric: true, layoutDirection: .leftToRight))

        try await check("prompt", Self.usersWindow + [
            .string("Rename"), .string(""), .string("OK"), .string("Anuluj"), .nothing, .nothing,
            InputPurpose.default.propValue, .string(""),
        ]) {
            _ = try await WindowSession().prompt("Rename")
        }
        try await check("alert", Self.usersWindow + [.string("Zapisano"), .string("Szkic jest bezpieczny"), .string("OK")]) {
            try await WindowSession().alert("Zapisano", message: "Szkic jest bezpieczny")
        }

        HostBoundary.setLocaleInfo(HostLocaleInfo(
            language: "", region: "", name: "", timeZone: "", uses24HourClock: false, firstDayOfWeek: .sunday,
            isMetric: true, layoutDirection: .leftToRight))
    }

    func testFocusingAViewCrossesWithItsArgumentsInPlace() async throws {
        try await check("focus", [.string("email")]) {
            _ = try await named("email", TextField.self).focus()
        }
    }

    func testUnfocusingAViewCrossesWithItsArgumentsInPlace() async throws {
        try await check("unfocus", [.string("email")]) {
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
        try await check("goBack", [.string("browser")]) {
            try await named("browser", WebView.self).goBack()
        }
    }

    func testGoingForwardInAWebViewCrossesWithItsArgumentsInPlace() async throws {
        try await check("goForward", [.string("browser")]) {
            try await named("browser", WebView.self).goForward()
        }
    }

    func testReloadingAWebViewCrossesWithItsArgumentsInPlace() async throws {
        try await check("reload", [.string("browser")]) {
            try await named("browser", WebView.self).reload()
        }
    }

    /// The one WebView act with a second argument: the script after the view,
    /// and an answer somebody is waiting for.
    func testRunningJavaScriptCrossesWithItsArgumentsInPlace() async throws {
        try await check("evaluateJavaScript", [.string("browser"), .string("document.title")]) {
            _ = try await named("browser", WebView.self).evaluateJavaScript("document.title")
        }
    }

    /// A list scrolls to an identity - a group's name before an item's where the
    /// list has groups - and says where it stands, after the view.
    func testScrollingAListCrossesWithItsArgumentsInPlace() async throws {
        try await check("scrollTo", [.string("list"), .string("500"), .enumeration(ScrollAnchor.start.rawValue)]) {
            try await named("list", ItemsView<Int>.self).scrollTo(500, anchor: .start)
        }
        try await check("scrollTo", [.string("list"), .string("Fruit\u{1F}Pear"), .enumeration(ScrollAnchor.nearest.rawValue)]) {
            try await named("list", ItemsView<String>.self).scrollTo("Pear", inGroup: "Fruit")
        }
    }

    /// A list of groups scrolls to an item by the identity its own source wrote for it - its group's name before it
    /// - without being told the group.
    func testScrollingAGroupedListFindsTheItemsGroup() async throws {
        let list = Aim(ItemsView<String>.self)
        let fruit = Section(["Apple", "Pear"]) { Text($0) }.id("Fruit")
        Renders().render(stack([ItemsView(groups: [fruit]).aim(list).node], id: "root"))
        drain()

        let task = Self.begin { try await list.scrollTo("Pear") }
        let batch = drain()

        XCTAssertEqual(batch.first?.arguments.dropFirst().first, .string("Fruit\u{1F}Pear"))

        await finish(batch)
        _ = try? await task.value
    }

    /// A map slides on its region after the view: one run of three numbers - latitude, longitude, and the radius in
    /// METERS.
    func testMovingAMapCrossesWithItsArgumentsInPlace() async throws {
        try await check("moveToRegion", [.string("map"), .numbers([52.2297, 21.0122, 3000])]) {
            try await named("map", Map.self).moveToRegion(
                MapRegion(center: Location(latitude: 52.2297, longitude: 21.0122), radiusMeters: 3000))
        }
    }

    func testAskingTheTimeCrossesWithItsArgumentsInPlace() async throws {
        try await check("currentTime", []) {
            _ = try? await ClockTime.now()
        }
    }

    func testAskingTheZoneCrossesWithItsArgumentsInPlace() async throws {
        try await check("currentTimeZone", []) {
            _ = try? await TimeZoneInfo.local()
        }
    }

    func testAskingForAnOffsetCrossesWithItsArgumentsInPlace() async throws {
        try await check("utcOffset", [.string("Europe/Warsaw"), .numbers([2026, 1, 15])]) {
            _ = try? await TimeZoneInfo.utcOffset(
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
            _ = try? await TimeZoneInfo.utcOffset(of: "Europe/Warsaw")
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
        application.colorScheme = .system
        taken(drain(), "useColorScheme", [.enumeration(ColorScheme.system.rawValue)], awaited: false)
    }

    func testAFailedHandlerCrossesWithItsArgumentsInPlace() throws {
        drain()
        Renderer.shared.report(StateUIError(message: "boom"))

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
            try await StandardEnvironment.application.clipboard.write(text: "Copied")
        }
    }

    /// The clipboard read, asked with no arguments, a handler waiting for its words.
    func testReadingTheClipboardCrossesWithItsArgumentsInPlace() async throws {
        try await check("readClipboard", []) {
            _ = try? await StandardEnvironment.application.clipboard.text()
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

    /// An address launched crosses as written.
    func testALinkCrossesAsWritten() async throws {
        try await check("launchLink", [.string("https://www.swift.org")]) {
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

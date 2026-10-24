// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A toolkit the tests answer for: what each act asked of it, and what it answers.
@MainActor
private final class Toolkit: ActToolkit {
    let host = "Test"
    var zones: [String: Int] = ["Europe/Warsaw": 120]
    var windowToAsk = true
    /// The window a question asks in.
    var window = HostActPerformerTests.window
    var shown: [(question: HostQuestion, answered: (Result<HostQuestion.Given, ActFailure>) -> Void)] = []
    /// The window each question was asked over, in turn; nil for the window the user is in.
    var over: [MountedElement?] = []
    /// The window each keyboard taken down was in, in turn; nil for the window the user is in.
    var keyboards: [MountedElement?] = []
    var announced: [String] = []
    var clipboard: String?
    var shares: [(shared: HostShare, answered: (Result<Bool, ActFailure>) -> Void)] = []
    var themes: [ColorScheme] = []
    var accents: [Color?] = []
    var takesAccent = true
    var focusable: Set<ElementID> = []
    var kept: [Act] = []
    var own: Set<Act> = []
    var registered: Set<Act> = []
    var logged: [String] = []

    func localTime() -> (hour: Int, minute: Int, second: Int, millisecond: Int) { (9, 30, 5, 250) }
    func localZone() -> String { "Europe/Warsaw" }
    func utcOffset(of zone: String?, on day: CalendarDate?) -> Int? { zones[zone ?? "Europe/Warsaw"] }

    func show(
        _ question: HostQuestion, over window: MountedElement?,
        answered: @escaping (Result<HostQuestion.Given, ActFailure>) -> Void
    ) -> MountedElement? {
        guard windowToAsk else { return nil }
        shown.append((question, answered))
        over.append(window)
        return window ?? self.window
    }

    func announce(_ words: String) { announced.append(words) }
    func writeClipboard(_ words: String) { clipboard = words }
    func readClipboard(answered: @escaping (Result<String?, ActFailure>) -> Void) { answered(.success(clipboard)) }
    func share(
        _ shared: HostShare, over window: MountedElement?, answered: @escaping (Result<Bool, ActFailure>) -> Void
    ) -> MountedElement? {
        guard windowToAsk else { return nil }
        shares.append((shared, answered))
        return window ?? self.window
    }
    func useColorScheme(_ theme: ColorScheme) { themes.append(theme) }
    func useAccentColor(_ accent: Color?) -> Bool {
        accents.append(accent)
        return takesAccent
    }
    func hideOnScreenKeyboard(in window: MountedElement?) -> Bool {
        keyboards.append(window)
        return true
    }

    func focus(_ element: MountedElement) -> Bool? {
        element.id == .manual("label") ? nil : focusable.contains(element.id)
    }

    func unfocus(_ element: MountedElement) -> Bool { element.id != .manual("label") }

    func keep(_ call: HostActCall) -> Bool {
        guard call.act == .persistValue else { return false }
        kept.append(call.act)
        return true
    }

    func performOwn(_ call: HostActCall) -> Bool { own.contains(call.act) }
    func performRegistered(_ call: HostActCall) -> Bool { registered.contains(call.act) }
    func log(_ message: String) { logged.append(message) }
}

/// The answers the performer gave, by the call's completion.
private final class Answers: ActAnswering {
    var replies: [Int: [HostValue]] = [:]
    var failures: [Int: String] = [:]

    func reply(_ call: HostActCall, _ values: [HostValue]) {
        if let completion = call.completion { replies[completion] = values }
    }

    func fail(_ call: HostActCall, _ reason: String, log: (String) -> Void) {
        if let completion = call.completion { failures[completion] = reason } else { log(reason) }
    }
}

/// A platform's networking the tests answer for: what was sent, and what the server says.
private final class Network: NetworkToolkit {
    var readsRelativeAddresses = false
    var sent: [HostRequest] = []
    var answer: Result<HostResponse, ActFailure> = .success(HostResponse(status: 200, headers: [], body: []))
    /// Whether the server holds its answer, the request under way.
    var holds = false
    var held: [(Result<HostResponse, ActFailure>) -> Void] = []
    var stopped: [String] = []

    func send(
        _ request: HostRequest, answered: @escaping (Result<HostResponse, ActFailure>) -> Void
    ) -> () -> Void {
        sent.append(request)
        if holds { held.append(answered) } else { answered(answer) }
        return { [weak self] in self?.stopped.append(request.address) }
    }
}

/// The acts every host performs, answered the same on each: the toolkit does its part, the performer the rest.
@MainActor
final class HostActPerformerTests: XCTestCase {
    private func performer(_ toolkit: Toolkit, _ answers: Answers, tree: MountedTree? = nil) -> HostActPerformer {
        HostActPerformer(toolkit: toolkit, answers: answers, tree: { tree })
    }

    /// Two windows of one tree, which the tests' questions ask in.
    private static let windows: (runtime: HostRuntime, first: MountedElement, second: MountedElement) = {
        let runtime = HostRuntime.still()
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([
            HostPatch(id: .manual("notes"), type: .window), HostPatch(id: .manual("drafts"), type: .window),
        ])
        runtime.tree.apply(root, complete: true)
        let windows = runtime.tree.root?.windows ?? []
        return (runtime, windows[0], windows[1])
    }()

    /// The window the tests' toolkits ask in, unless a test says another.
    static var window: MountedElement { windows.first }

    /// A request reaches the platform as the application sent it, and the server's answer comes back as every host
    /// answers it: its status, the headers' names in lowercase - one said twice joined, sorted by name - and its body.
    /// A status is an answer; no answer at all fails the call with the platform's reason.
    func testARequestIsSentAndItsAnswerComesBackAlike() {
        let (network, answers) = (Network(), Answers())
        let acts = HostActPerformer(toolkit: Toolkit(), network: network, answers: answers, tree: { nil })
        network.answer = .success(HostResponse(status: 404, headers: [
            HostHeader(name: "Set-Cookie", value: "a=1"), HostHeader(name: "Content-Type", value: "text/plain"),
            HostHeader(name: "set-cookie", value: "b=2"),
        ], body: Array("Not here".utf8)))

        acts.perform(HostActCall(act: .sendRequest, arguments: [
            .string("https://example.com/parcels"), .name("post"), .strings(["Accept", "json"]), .bytes([1, 2]),
        ], completion: 1))
        network.answer = .failure(ActFailure("the server could not be found"))
        acts.perform(HostActCall(act: .sendRequest, arguments: [
            .string("https://nowhere.example"), .name("GET"), .strings([]), .bytes([]),
        ], completion: 2))

        XCTAssertEqual(network.sent.first, HostRequest(
            address: "https://example.com/parcels", method: "POST", headers: [HostHeader(name: "Accept", value: "json")],
            body: [1, 2]))
        XCTAssertEqual(answers.replies[1], [
            .number(404), .strings(["content-type", "text/plain", "set-cookie", "a=1, b=2"]), .bytes(Array("Not here".utf8)),
        ])
        XCTAssertEqual(answers.failures[2], "the server could not be found")
    }

    /// An address with no scheme is read against a page, where one stands - the Web's; elsewhere it fails before
    /// anything is sent. A host with no networking says it performs no requests.
    func testAnAddressWithNoSchemeIsSentOnlyWhereAPageReadsIt() {
        let (network, answers) = (Network(), Answers())
        let acts = HostActPerformer(toolkit: Toolkit(), network: network, answers: answers, tree: { nil })
        let relative: [HostValue] = [.string("/api/parcels"), .name("GET"), .strings([]), .bytes([])]

        acts.perform(HostActCall(act: .sendRequest, arguments: relative, completion: 1))
        network.readsRelativeAddresses = true
        acts.perform(HostActCall(act: .sendRequest, arguments: relative, completion: 2))
        performer(Toolkit(), answers).perform(HostActCall(act: .sendRequest, arguments: relative, completion: 3))

        XCTAssertEqual(
            answers.failures[1], "the address '/api/parcels' names no scheme, and no page stands to read it against")
        XCTAssertEqual(network.sent.map(\.address), ["/api/parcels"], "sent where a page reads it")
        XCTAssertEqual(answers.failures[3]?.contains("does not perform the act 'sendRequest'"), true)
        XCTAssertFalse(HostRequest(address: "parcels/42").namesItsScheme)
        XCTAssertTrue(HostRequest(address: "http://localhost:8080").namesItsScheme)
    }

    /// A call whose caller's run ended is stopped: a request under way through what the platform's networking
    /// answered for it, once; one already answered has nothing left to stop.
    func testARequestWhoseCallerWentIsStopped() {
        let (network, answers) = (Network(), Answers())
        let acts = HostActPerformer(toolkit: Toolkit(), network: network, answers: answers, tree: { nil })
        let asked: [HostValue] = [.string("https://example.com/held"), .name("GET"), .strings([]), .bytes([])]

        acts.perform(HostActCall(act: .sendRequest, arguments: [.string("https://example.com")] + asked.dropFirst(),
                                 completion: 1))
        network.holds = true
        acts.perform(HostActCall(act: .sendRequest, arguments: asked, completion: 2))
        acts.perform(HostActCall(act: .cancelCall, arguments: [.number(1)], completion: nil))
        acts.perform(HostActCall(act: .cancelCall, arguments: [.number(2)], completion: nil))
        acts.perform(HostActCall(act: .cancelCall, arguments: [.number(2)], completion: nil))

        XCTAssertEqual(network.stopped, ["https://example.com/held"], "the request under way, stopped once")
    }

    /// A question whose caller's run ended before its turn leaves the queue unasked; one showing stays for the user.
    func testAQuestionWhoseCallerWentIsNeverAsked() {
        let (toolkit, answers) = (Toolkit(), Answers())
        let acts = performer(toolkit, answers)

        acts.perform(HostActCall(act: .confirm, arguments: HostActCall.usersWindow + [.string("Delete?")], completion: 1))
        acts.perform(HostActCall(act: .alert, arguments: HostActCall.usersWindow + [.string("Done")], completion: 2))
        acts.perform(HostActCall(act: .alert, arguments: HostActCall.usersWindow + [.string("Saved")], completion: 3))
        acts.perform(HostActCall(act: .cancelCall, arguments: [.number(2)], completion: nil))
        acts.perform(HostActCall(act: .cancelCall, arguments: [.number(1)], completion: nil))
        toolkit.shown[0].answered(.success(.init(accepted: true)))

        XCTAssertEqual(toolkit.shown.map(\.question.title), ["Delete?", "Saved"], "the one gone, never shown")
    }

    /// The time and the zones are the toolkit's, answered as every host answers them; a zone nobody knows fails
    /// with the reason.
    func testTheTimeAndTheZonesAreAnswered() {
        let (toolkit, answers) = (Toolkit(), Answers())
        let acts = performer(toolkit, answers)

        acts.perform(HostActCall(act: .currentTime, arguments: [], completion: 1))
        acts.perform(HostActCall(act: .currentTimeZone, arguments: [], completion: 2))
        acts.perform(HostActCall(act: .utcOffset, arguments: [.string("Europe/Warsaw")], completion: 3))
        acts.perform(HostActCall(act: .utcOffset, arguments: [.string("Nowhere/Else")], completion: 4))

        XCTAssertEqual(answers.replies[1], HostActs.currentTime(hour: 9, minute: 30, second: 5, millisecond: 250))
        XCTAssertEqual(answers.replies[2], [.string("Europe/Warsaw")])
        XCTAssertEqual(answers.replies[3], [.number(120)])
        XCTAssertEqual(answers.failures[4], "no time zone 'Nowhere/Else' is known")
    }

    /// Questions show one at a time: answering the one showing answers its caller and shows the next; with no window
    /// to ask in, a question fails and the next still shows.
    func testQuestionsShowOneAtATime() throws {
        let (toolkit, answers) = (Toolkit(), Answers())
        let acts = performer(toolkit, answers)

        acts.perform(HostActCall(act: .confirm, arguments: HostActCall.usersWindow + [.string("Delete?")], completion: 1))
        acts.perform(HostActCall(act: .alert, arguments: HostActCall.usersWindow + [.string("Done")], completion: 2))
        XCTAssertEqual(toolkit.shown.map(\.question.title), ["Delete?"], "the second waits")

        toolkit.shown[0].answered(.success(.init(accepted: true)))
        XCTAssertEqual(answers.replies[1], [.bool(true)])
        XCTAssertEqual(toolkit.shown.map(\.question.title), ["Delete?", "Done"], "then the next shows")

        toolkit.windowToAsk = false
        acts.perform(HostActCall(act: .alert, arguments: HostActCall.usersWindow + [.string("Lost")], completion: 3))
        toolkit.shown[1].answered(.success(.init(accepted: true)))
        XCTAssertEqual(answers.failures[3], "there is no window to ask the user in")
    }

    /// A question asks over the window it names - its scene's key and its own, as one key stands in two scenes -
    /// and one naming none over the window the user is in; one whose window closed while it waited is answered as
    /// the user dismissing it does, and the next shows. The keyboard is taken down in the window named; in one
    /// closed nothing holds it.
    func testAQuestionAsksOverTheWindowItNames() throws {
        let runtime = HostRuntime.still()
        var root = HostPatch(id: .manual("application"), type: .application)
        root.children = .arranged(["1", "2"].map { name in
            var scene = HostPatch(id: .manual(name), type: .scene)
            scene.children = .arranged([HostPatch(id: .manual("window 1"), type: .window)])
            return scene
        })
        runtime.tree.apply(root, complete: true)
        let second = try XCTUnwrap(runtime.tree.root?.first(id: .manual("2"))?.first(id: .manual("window 1")))
        let (toolkit, answers) = (Toolkit(), Answers())
        let acts = performer(toolkit, answers, tree: runtime.tree)

        acts.perform(HostActCall(
            act: .confirm, arguments: HostActCall.window("window 1", of: "2") + [.string("Delete?")], completion: 1))
        acts.perform(HostActCall(act: .alert, arguments: HostActCall.usersWindow + [.string("Done")], completion: 2))
        acts.perform(HostActCall(
            act: .alert, arguments: HostActCall.window("window 7", of: "1") + [.string("Gone")], completion: 3))
        acts.perform(HostActCall(act: .alert, arguments: HostActCall.usersWindow + [.string("Last")], completion: 4))
        XCTAssertTrue(try XCTUnwrap(toolkit.over.first) === second, "over the second scene's window")

        toolkit.shown[0].answered(.success(.init(accepted: true)))
        XCTAssertNil(try XCTUnwrap(toolkit.over.last), "then over the window the user is in")
        toolkit.shown[1].answered(.success(.init(accepted: true)))

        XCTAssertEqual(answers.replies[3], [], "a window not open answers as the user dismissing it")
        XCTAssertEqual(toolkit.shown.map(\.question.title), ["Delete?", "Done", "Last"], "and the next shows")

        acts.perform(HostActCall(
            act: .hideOnScreenKeyboard, arguments: HostActCall.window("window 1", of: "2"), completion: 5))
        acts.perform(HostActCall(
            act: .hideOnScreenKeyboard, arguments: HostActCall.window("window 7", of: "2"), completion: 6))
        XCTAssertTrue(try XCTUnwrap(toolkit.keyboards.first) === second)
        XCTAssertEqual(toolkit.keyboards.count, 1)
        XCTAssertEqual(answers.replies[5], [.bool(true)])
        XCTAssertEqual(answers.replies[6], [.bool(false)], "a closed window holds no keyboard")
    }

    /// A question the toolkit could not show fails its call with the toolkit's reason - no answer of the user's - and
    /// the next shows.
    func testAQuestionTheToolkitCouldNotShowFailsItsCall() {
        let (toolkit, answers) = (Toolkit(), Answers())
        let acts = performer(toolkit, answers)

        acts.perform(HostActCall(act: .confirm, arguments: HostActCall.usersWindow + [.string("Delete?")], completion: 1))
        acts.perform(HostActCall(act: .alert, arguments: HostActCall.usersWindow + [.string("Done")], completion: 2))
        toolkit.shown[0].answered(.failure(ActFailure("another dialog stands over the window")))

        XCTAssertNil(answers.replies[1], "no answer of the user's")
        XCTAssertEqual(answers.failures[1], "another dialog stands over the window")
        XCTAssertEqual(toolkit.shown.map(\.question.title), ["Delete?", "Done"], "then the next shows")
    }

    /// The focus goes to the element the act names: whether it took it is the answer; an element with no view, or
    /// one not on screen, fails.
    func testTheFocusGoesWhereTheActAimsIt() {
        let runtime = HostRuntime.still()
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([
            HostPatch(id: .manual("field"), type: .textField), HostPatch(id: .manual("label"), type: .text),
        ])
        runtime.tree.apply(root, complete: true)
        let (toolkit, answers) = (Toolkit(), Answers())
        toolkit.focusable = [.manual("field")]
        let acts = performer(toolkit, answers, tree: runtime.tree)

        acts.perform(HostActCall(act: .focus, arguments: [.string("field")], completion: 1))
        acts.perform(HostActCall(act: .focus, arguments: [.string("label")], completion: 2))
        acts.perform(HostActCall(act: .unfocus, arguments: [.string("field")], completion: 3))
        acts.perform(HostActCall(act: .focus, arguments: [.string("gone")], completion: 4))

        XCTAssertEqual(answers.replies[1], [.bool(true)])
        XCTAssertEqual(answers.failures[2], "manual(\"label\") has no view")
        XCTAssertEqual(answers.replies[3], [])
        XCTAssertNotNil(answers.failures[4])
    }

    /// A value is kept where the toolkit keeps it; a control's own act and the application's are theirs; an act
    /// nobody performs fails by name and the host's.
    func testWhatNoToolkitPerformsFailsByName() {
        let (toolkit, answers) = (Toolkit(), Answers())
        toolkit.own = [Act("WebView.GoBack")]
        toolkit.registered = [Act("Mine.Act")]
        let acts = performer(toolkit, answers)

        acts.perform(HostActCall(act: .persistValue, arguments: [], completion: 1))
        acts.perform(HostActCall(act: Act("WebView.GoBack"), arguments: [], completion: 2))
        acts.perform(HostActCall(act: Act("Mine.Act"), arguments: [], completion: 3))
        acts.perform(HostActCall(act: .persistSceneValue, arguments: [], completion: 4))
        acts.perform(HostActCall(act: .announce, arguments: [.string("Saved")], completion: 5))

        XCTAssertEqual(answers.replies[1], [])
        XCTAssertNil(answers.replies[2], "a control's own act answers itself")
        XCTAssertNil(answers.failures[3], "and the application's")
        XCTAssertEqual(answers.failures[4], "the Test host does not perform the act '\(Act.persistSceneValue.name)'")
        XCTAssertEqual(toolkit.announced, ["Saved"])
        XCTAssertEqual(answers.replies[5], [])
    }

    /// The clipboard is the toolkit's: words written are read back, and an empty clipboard reads as nothing.
    func testTheClipboardIsTheToolkits() {
        let (toolkit, answers) = (Toolkit(), Answers())
        let acts = performer(toolkit, answers)

        acts.perform(HostActCall(act: .readClipboard, arguments: [], completion: 1))
        acts.perform(HostActCall(act: .writeClipboard, arguments: [.string("Copied")], completion: 2))
        acts.perform(HostActCall(act: .readClipboard, arguments: [], completion: 3))

        XCTAssertEqual(answers.replies[1], [.nothing], "an empty clipboard")
        XCTAssertEqual(answers.replies[2], [])
        XCTAssertEqual(answers.replies[3], [.string("Copied")])
    }

    /// The application's theme is the toolkit's to show, and the theme in force the core resolves against: the
    /// application's while it holds one, the system's again once it follows it.
    func testTheApplicationsThemeIsShownAndInForce() {
        let (toolkit, answers) = (Toolkit(), Answers())
        let acts = performer(toolkit, answers)
        defer { acts.perform(HostActCall(act: .useColorScheme, arguments: [ColorScheme.system.propValue], completion: nil)) }
        CoreLink().setColorScheme(.light)

        acts.perform(HostActCall(act: .useColorScheme, arguments: [ColorScheme.dark.propValue], completion: 1))
        XCTAssertEqual(toolkit.themes, [.dark])
        XCTAssertEqual(answers.replies[1], [])
        XCTAssertEqual(StandardEnvironment.application.info.colorScheme, .dark, "the application's, over the system's")

        CoreLink().setColorScheme(.light)
        XCTAssertEqual(StandardEnvironment.application.info.colorScheme, .dark, "a system report leaves it held")

        acts.perform(HostActCall(act: .useColorScheme, arguments: [ColorScheme.system.propValue], completion: 2))
        XCTAssertEqual(toolkit.themes, [.dark, .system])
        XCTAssertEqual(StandardEnvironment.application.info.colorScheme, .light, "the system's again")
    }

    /// The application's accent stands where the toolkit takes it - a platform whose user chooses none - over the
    /// accent the platform reports, until the application gives it back; where the toolkit does not, the user's
    /// stays in force.
    func testTheApplicationsAccentStandsWhereThePlatformTakesIt() {
        let (toolkit, answers) = (Toolkit(), Answers())
        let acts = performer(toolkit, answers)
        defer { acts.perform(HostActCall(act: .useAccentColor, arguments: [.nothing], completion: nil)) }
        let (brick, own, user) = (Color.firebrick, Color(hex: 0x0A84FF), Color(hex: 0x00AA55))
        CoreLink().setAccentColor(own)

        acts.perform(HostActCall(act: .useAccentColor, arguments: [brick.propValue], completion: 1))
        XCTAssertEqual(toolkit.accents, [brick])
        XCTAssertEqual(answers.replies[1], [])
        XCTAssertEqual(StandardEnvironment.application.info.accentColor, brick, "the application's, where it was taken")
        CoreLink().setAccentColor(own)
        XCTAssertEqual(StandardEnvironment.application.info.accentColor, brick, "a platform's report leaves it held")

        acts.perform(HostActCall(act: .useAccentColor, arguments: [.nothing], completion: 2))
        XCTAssertEqual(toolkit.accents, [brick, nil])
        XCTAssertEqual(StandardEnvironment.application.info.accentColor, own, "the platform's again")

        toolkit.takesAccent = false
        CoreLink().setAccentColor(user)
        acts.perform(HostActCall(act: .useAccentColor, arguments: [brick.propValue], completion: 3))
        XCTAssertEqual(StandardEnvironment.application.info.accentColor, user, "the user's, where the platform has one")
    }

    // MARK: - Files

    private let report = ChosenFile(address: "C:\\Reports\\Report.html", name: "Report.html")

    /// A file dialog waits its turn among the questions, and a question behind it waits for it; its caller hears the
    /// files chosen, or why the toolkit failed.
    func testAFileDialogWaitsItsTurnAmongTheQuestions() throws {
        let (toolkit, files, answers) = (Toolkit(), Files(), Answers())
        let acts = HostActPerformer(toolkit: toolkit, files: files, answers: answers, tree: { nil })

        acts.perform(HostActCall(act: .confirm, arguments: HostActCall.usersWindow + [.string("Delete?")], completion: 1))
        acts.perform(HostActCall(act: .openFiles, arguments: HostActCall.usersWindow + [[FileType]().propValue, .bool(true)], completion: 2))
        acts.perform(HostActCall(act: .alert, arguments: HostActCall.usersWindow + [.string("Done")], completion: 3))
        acts.perform(HostActCall(
            act: .saveFile, arguments: HostActCall.usersWindow + [[UInt8]([7]).propValue, .string("Report"), [FileType]().propValue],
            completion: 4))
        XCTAssertTrue(files.shown.isEmpty, "the dialog waits for the question")

        toolkit.shown[0].answered(.success(.init(accepted: true)))
        XCTAssertEqual(files.shown.map(\.dialog.kind), [.openSeveral], "then shows")
        XCTAssertEqual(toolkit.shown.count, 1, "and the question behind it waits for it")

        files.shown[0].answered(.success([report]))
        XCTAssertEqual(answers.replies[2], [[report].propValue])
        toolkit.shown[1].answered(.success(.init(accepted: true)))
        XCTAssertEqual(files.shown.map(\.dialog.contents), [[], [7]])

        files.shown[1].answered(.failure(ActFailure("the disk is full")))
        XCTAssertEqual(answers.failures[4], "the disk is full")
    }

    /// A share sheet waits its turn among the questions; its caller hears whether the user shared, and a sheet whose
    /// window went answers that they did not.
    func testAShareSheetWaitsItsTurnAndAnswersWhetherShared() throws {
        let (toolkit, answers) = (Toolkit(), Answers())
        let acts = performer(toolkit, answers)

        acts.perform(HostActCall(act: .confirm, arguments: HostActCall.usersWindow + [.string("Send?")], completion: 1))
        acts.perform(HostActCall(
            act: .share, arguments: HostActCall.usersWindow + [.string("Notes"), .string("https://example.com")],
            completion: 2))
        acts.perform(HostActCall(act: .share, arguments: HostActCall.usersWindow + [.nothing, .nothing], completion: 3))
        XCTAssertTrue(toolkit.shares.isEmpty, "the sheet waits for the question")
        XCTAssertEqual(answers.failures[3], "the act offers nothing to share")

        toolkit.shown[0].answered(.success(.init(accepted: true)))
        XCTAssertEqual(toolkit.shares.map(\.shared), [HostShare(text: "Notes", link: "https://example.com")])
        XCTAssertEqual(toolkit.shares[0].shared.together, "Notes\nhttps://example.com")
        toolkit.shares[0].answered(.success(true))
        XCTAssertEqual(answers.replies[2], [.bool(true)])

        acts.perform(HostActCall(act: .share, arguments: HostActCall.usersWindow + [.nothing, .string("https://swift.org")], completion: 4))
        acts.dismissAll()
        XCTAssertEqual(answers.replies[4], [.bool(false)], "a sheet whose window went: not shared")
    }

    /// A question whose dialog went with its window is asked again in the next: answered there, its caller hears
    /// it, and the dialog that went answers nothing. A file dialog stands in the platform's own window, which
    /// answers the next, and is not asked again.
    func testAQuestionWhoseDialogWentIsAskedAgain() throws {
        let (toolkit, files, answers) = (Toolkit(), Files(), Answers())
        let acts = HostActPerformer(toolkit: toolkit, files: files, answers: answers, tree: { nil })
        acts.perform(HostActCall(act: .confirm, arguments: HostActCall.usersWindow + [.string("Delete?")], completion: 1))

        acts.askAgain()
        XCTAssertEqual(toolkit.shown.map(\.question.title), ["Delete?", "Delete?"])
        toolkit.shown[0].answered(.success(.init(accepted: true)))
        XCTAssertNil(answers.replies[1], "the dialog that went answers nothing")
        toolkit.shown[1].answered(.success(.init(accepted: false)))
        XCTAssertEqual(answers.replies[1], [.bool(false)])

        acts.perform(HostActCall(act: .openFiles, arguments: HostActCall.usersWindow + [[FileType]().propValue, .bool(true)], completion: 2))
        acts.askAgain()
        XCTAssertEqual(files.shown.count, 1, "a file dialog is not asked again")
    }

    /// Every question waiting - the one showing and those behind it - is answered as dismissed once the window it
    /// was asked in goes for good: a confirmation not accepted, a file dialog with nothing chosen; none waits on.
    func testEveryQuestionWaitingIsDismissedWhenTheWindowGoes() throws {
        let (toolkit, files, answers) = (Toolkit(), Files(), Answers())
        let acts = HostActPerformer(toolkit: toolkit, files: files, answers: answers, tree: { nil })
        acts.perform(HostActCall(act: .confirm, arguments: HostActCall.usersWindow + [.string("Delete?")], completion: 1))
        acts.perform(HostActCall(act: .openFiles, arguments: HostActCall.usersWindow + [[FileType]().propValue, .bool(true)], completion: 2))

        acts.dismissAll()
        toolkit.shown[0].answered(.success(.init(accepted: true)))

        XCTAssertEqual(answers.replies[1], [.bool(false)], "not accepted, and the late answer counts for nothing")
        XCTAssertEqual(answers.replies[2], [[ChosenFile]().propValue], "nothing chosen")
        acts.perform(HostActCall(act: .alert, arguments: HostActCall.usersWindow + [.string("Next")], completion: 3))
        XCTAssertEqual(toolkit.shown.last?.question.title, "Next", "the next shows at once")
    }

    /// What was asked over a window that went - a question, a file dialog - is answered as the user dismissing it
    /// does, as nobody is left to answer it, and the next asks at once; what was asked over a window still open
    /// waits on, and an answer the dialog of a window gone gives later counts for nothing.
    func testWhatWasAskedOverAWindowThatWentIsDismissed() throws {
        let (toolkit, files, answers) = (Toolkit(), Files(), Answers())
        let acts = HostActPerformer(toolkit: toolkit, files: files, answers: answers, tree: { nil })
        let (notes, drafts) = (Self.windows.first, Self.windows.second)
        acts.perform(HostActCall(act: .confirm, arguments: HostActCall.usersWindow + [.string("Delete?")], completion: 1))
        files.window = drafts
        acts.perform(HostActCall(act: .openFiles, arguments: HostActCall.usersWindow + [[FileType]().propValue, .bool(true)], completion: 2))

        acts.windowsOpen([notes, drafts])
        XCTAssertNil(answers.replies[1], "its window stands: it waits on")

        acts.windowsOpen([drafts])
        toolkit.shown[0].answered(.success(.init(accepted: true)))
        XCTAssertEqual(answers.replies[1], [.bool(false)], "not accepted; the late answer counts for nothing")
        XCTAssertEqual(files.shown.count, 1, "the next asks at once")

        acts.windowsOpen([drafts])
        XCTAssertNil(answers.replies[2], "its window stands")
        acts.windowsOpen([])
        XCTAssertEqual(answers.replies[2], [[ChosenFile]().propValue], "nothing chosen")
    }

    /// A link the user chose opens its address as a launched one opens, and answers no one.
    func testALinksAddressOpensAsALaunchedOne() {
        let (files, answers) = (Files(), Answers())
        let acts = HostActPerformer(toolkit: Toolkit(), files: files, answers: answers, tree: { nil })

        acts.open(link: "https://www.swift.org/about")

        XCTAssertEqual(files.launched, ["https://www.swift.org/about"])
        XCTAssertTrue(answers.replies.isEmpty && answers.failures.isEmpty, "no caller to answer")
    }

    /// A file is read and launched, and an address launched, as the toolkit answers.
    func testAFileIsReadAndLaunchedAndAnAddressLaunched() {
        let (files, answers) = (Files(), Answers())
        let acts = HostActPerformer(toolkit: Toolkit(), files: files, answers: answers, tree: { nil })
        files.contents = [report: [60, 104, 49, 62]]

        acts.perform(HostActCall(act: .readFile, arguments: [report.propValue], completion: 1))
        acts.perform(HostActCall(
            act: .readFile, arguments: [ChosenFile(address: "gone", name: "gone").propValue], completion: 2))
        acts.perform(HostActCall(act: .launchFile, arguments: [report.propValue], completion: 3))
        acts.perform(HostActCall(act: .launchLink, arguments: [.string("https://www.swift.org")], completion: 4))
        acts.perform(HostActCall(act: .readFile, arguments: [], completion: 5))

        XCTAssertEqual(answers.replies[1], [.bytes([60, 104, 49, 62])])
        XCTAssertEqual(answers.failures[2], "no file 'gone'")
        XCTAssertEqual(answers.replies[3], [.bool(true)])
        XCTAssertEqual(answers.replies[4], [.bool(false)])
        XCTAssertEqual(files.launched, ["Report.html", "https://www.swift.org"])
        XCTAssertEqual(answers.failures[5], "the act names no file")
    }

    /// A read says the most bytes it takes, which reaches the toolkit as it is said - nothing for a whole file, and
    /// none below nought.
    func testAReadSaysTheMostBytesItTakes() {
        let (files, answers) = (Files(), Answers())
        let acts = HostActPerformer(toolkit: Toolkit(), files: files, answers: answers, tree: { nil })
        files.contents = [report: [60, 104, 49, 62]]

        acts.perform(HostActCall(act: .readFile, arguments: [report.propValue, .number(2)], completion: 1))
        acts.perform(HostActCall(act: .readFile, arguments: [report.propValue, .nothing], completion: 2))
        acts.perform(HostActCall(act: .readFile, arguments: [report.propValue, .number(-3)], completion: 3))

        XCTAssertEqual(files.maxima, [2, nil, 0])
        XCTAssertEqual(answers.replies[1], [.bytes([60, 104])], "the first two bytes")
        XCTAssertEqual(answers.replies[2], [.bytes([60, 104, 49, 62])], "the whole file")
        XCTAssertEqual(answers.replies[3], [.bytes([])], "none")
    }

    /// A host with no toolkit for files fails every act for files by name and the host's.
    func testAHostWithNoFilesFailsTheirActsByName() {
        let answers = Answers()
        let acts = performer(Toolkit(), answers)

        for (completion, act) in [Act.openFiles, .saveFile, .readFile, .launchFile, .launchLink].enumerated() {
            acts.perform(HostActCall(act: act, arguments: [], completion: completion))
            XCTAssertEqual(answers.failures[completion], "the Test host does not perform the act '\(act.name)'")
        }
    }
}

/// A toolkit for files the tests answer for: the dialogs shown, the files it reads, what it launched.
@MainActor
private final class Files: FileToolkit {
    var shown: [(dialog: HostFileDialog, answered: (Result<[ChosenFile], ActFailure>) -> Void)] = []
    /// The window a dialog asks in.
    var window = HostActPerformerTests.window
    var contents: [ChosenFile: [UInt8]] = [:]
    var launched: [String] = []

    func show(
        _ dialog: HostFileDialog, over window: MountedElement?,
        answered: @escaping (Result<[ChosenFile], ActFailure>) -> Void
    ) -> MountedElement? {
        shown.append((dialog, answered))
        return window ?? self.window
    }

    /// The most bytes each read asked for, in turn; nil for a whole file.
    var maxima: [Int?] = []

    func read(_ file: ChosenFile, atMost maximum: Int?, answered: @escaping (Result<[UInt8], ActFailure>) -> Void) {
        maxima.append(maximum)
        let read = contents[file].map { bytes in maximum.map { Array(bytes.prefix($0)) } ?? bytes }
        answered(read.map { .success($0) } ?? .failure(ActFailure("no file '\(file.name)'")))
    }

    func launch(_ file: ChosenFile, answered: @escaping (Bool) -> Void) {
        launched.append(file.name)
        answered(true)
    }

    func launch(address: String, answered: @escaping (Bool) -> Void) {
        launched.append(address)
        answered(false)
    }
}

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
    var shown: [(question: HostQuestion, answered: (Bool, String?) -> Void)] = []
    var announced: [String] = []
    var focusable: Set<ElementId> = []
    var kept: [Act] = []
    var own: Set<Act> = []
    var registered: Set<Act> = []
    var logged: [String] = []

    func localTime() -> (hour: Int, minute: Int, second: Int, millisecond: Int) { (9, 30, 5, 250) }
    func localZone() -> String { "Europe/Warsaw" }
    func utcOffset(of zone: String?, on day: CalendarDate?) -> Int? { zones[zone ?? "Europe/Warsaw"] }

    func show(_ question: HostQuestion, answered: @escaping (Bool, String?) -> Void) -> Bool {
        guard windowToAsk else { return false }
        shown.append((question, answered))
        return true
    }

    func announce(_ words: String) { announced.append(words) }
    func hideOnScreenKeyboard() -> Bool { true }

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

/// The acts every host performs, answered the same on each: the toolkit does its part, the performer the rest.
@MainActor
final class HostActPerformerTests: XCTestCase {
    private func performer(_ toolkit: Toolkit, _ answers: Answers, tree: MountedTree? = nil) -> HostActPerformer {
        HostActPerformer(toolkit: toolkit, answers: answers, tree: { tree })
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

        acts.perform(HostActCall(act: .confirm, arguments: [.string("Delete?")], completion: 1))
        acts.perform(HostActCall(act: .alert, arguments: [.string("Done")], completion: 2))
        XCTAssertEqual(toolkit.shown.map(\.question.title), ["Delete?"], "the second waits")

        toolkit.shown[0].answered(true, nil)
        XCTAssertEqual(answers.replies[1], [.bool(true)])
        XCTAssertEqual(toolkit.shown.map(\.question.title), ["Delete?", "Done"], "then the next shows")

        toolkit.windowToAsk = false
        acts.perform(HostActCall(act: .alert, arguments: [.string("Lost")], completion: 3))
        toolkit.shown[1].answered(true, nil)
        XCTAssertEqual(answers.failures[3], "there is no window to ask the user in")
    }

    /// The focus goes to the element the act names: whether it took it is the answer; an element with no view, or
    /// none named, fails.
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
        toolkit.own = ["WebView.GoBack"]
        toolkit.registered = ["Mine.Act"]
        let acts = performer(toolkit, answers)

        acts.perform(HostActCall(act: .persistValue, arguments: [], completion: 1))
        acts.perform(HostActCall(act: "WebView.GoBack", arguments: [], completion: 2))
        acts.perform(HostActCall(act: "Mine.Act", arguments: [], completion: 3))
        acts.perform(HostActCall(act: .persistSceneValue, arguments: [], completion: 4))
        acts.perform(HostActCall(act: .announce, arguments: [.string("Saved")], completion: 5))

        XCTAssertEqual(answers.replies[1], [])
        XCTAssertNil(answers.replies[2], "a control's own act answers itself")
        XCTAssertNil(answers.failures[3], "and the application's")
        XCTAssertEqual(answers.failures[4], "the Test host does not perform the act '\(Act.persistSceneValue.name)'")
        XCTAssertEqual(toolkit.announced, ["Saved"])
        XCTAssertEqual(answers.replies[5], [])
    }
}

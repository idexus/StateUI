// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A control wears the page's stylesheet wherever it stands - in the window's room, on a sheet, over every page, in a
/// popover - and takes a tap at once there. The browser draws, so the suite runs it in a browser
/// (`test-web.sh --browser`).
@MainActor
final class WebLookTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testAControlOnASheetWearsTheStylesheet() throws {
        let host = WebRenderer.running {
            Text("Beneath").sheet(isPresented: State(wrappedValue: true).projectedValue) {
                VStack { Switch(true); Button("Done") }
            }
        }
        host.settle { (try? WebBrowser.number("document.querySelectorAll('dialog[open]').length", on: 0)) == 1 }

        XCTAssertEqual(try look("dialog[open] input.stateui-switch", "appearance"), "none", "the page's switch")
        XCTAssertEqual(try look("dialog[open] .stateui-sheet-room button", "touchAction"), "manipulation", "a tap at once")
    }

    func testAControlInAPopoverWearsTheStylesheet() throws {
        let host = WebRenderer.running {
            Button("Filters").popover(isPresented: State(wrappedValue: true).projectedValue) {
                VStack { Switch(true); Button("Done") }
            }
        }
        host.settle { (try? WebBrowser.number("document.querySelectorAll('.stateui-popover input').length", on: 0)) == 1 }

        XCTAssertEqual(try look(".stateui-popover input.stateui-switch", "appearance"), "none", "the page's switch")
        XCTAssertEqual(try look(".stateui-popover button", "touchAction"), "manipulation", "a tap at once")
    }

    /// A question stands as tall as what it says, its buttons side by side at their own height - also where the
    /// browser stretches a modal dialog with no height of its own over the window, as WebKit does.
    func testAQuestionStandsAsTallAsWhatItSays() throws {
        _ = WebRenderer.running { Text("Beneath") }
        let call = HostActCall(
            act: .confirm,
            arguments: [
                .string(""), .string(""), .string("Delete draft?"), .string("Gone for good"), .string("Delete"),
                .string("Keep"),
            ],
            completion: nil)
        let asked = WebQuestion(try XCTUnwrap(HostQuestion(call))) { _ in }
        asked.show()
        try withExtendedLifetime(asked) {
            let dialog = "document.querySelector('dialog.stateui-question[open]')"
            let height = try XCTUnwrap(WebBrowser.number("\(dialog).getBoundingClientRect().height", on: 0))
            let window = try XCTUnwrap(WebBrowser.number("innerHeight", on: 0))
            let buttons = try XCTUnwrap(WebBrowser.evaluate(
                "[...\(dialog).querySelectorAll('button')].map(b => { const r = b.getBoundingClientRect(); return r.top + ',' + r.height; }).join(';')",
                on: 0))
            XCTAssertLessThan(height, window / 2, "the dialog as tall as what it says")
            let places = buttons.split(separator: ";").map { $0.split(separator: ",").compactMap { Double($0) } }
            XCTAssertEqual(places.count, 2)
            XCTAssertEqual(places.map { $0[0] }.max(), places.map { $0[0] }.min(), "the buttons side by side")
            XCTAssertLessThan(places.map { $0[1] }.max() ?? 0, 60, "each at its own height")
        }
    }

    /// A popover stands as tall as what it holds: its height is the page's `auto`, never the browser's own
    /// `fit-content`, which WebKit stretches over the whole window.
    func testAPopoverStandsAsTallAsWhatItHolds() throws {
        let host = WebRenderer.running {
            Button("Filters").popover(isPresented: State(wrappedValue: true).projectedValue) {
                VStack { Switch(true); Button("Done") }
            }
        }
        let popover = "document.querySelector('.stateui-popover:popover-open')"
        host.settle { (try? WebBrowser.number("\(popover) ? 1 : 0", on: 0)) == 1 }

        let height = try XCTUnwrap(WebBrowser.number("\(popover).getBoundingClientRect().height", on: 0))
        let window = try XCTUnwrap(WebBrowser.number("innerHeight", on: 0))
        let declared = try WebBrowser.evaluate("""
            [...document.styleSheets].flatMap(s => { try { return [...s.cssRules]; } catch { return []; } })
              .filter(r => r.style?.height && \(popover).matches(r.selectorText)).map(r => r.style.height).join(" | ")
            """, on: 0)
        XCTAssertLessThan(height, window / 2, "as tall as what it holds")
        XCTAssertEqual(declared, "auto", "the page's height, not the browser's")
    }

    /// A sheet stands as large as its page asks, within the dialog's room; one holding a stack, whose pages come and
    /// go, at the dialog's standard size. Its parts stand in a column: WebKit stretches a modal dialog laid out as a
    /// grid over the window, whatever height it asks.
    func testASheetStandsAsLargeAsItsPageAndAStacksAtTheStandardSize() throws {
        let host = WebRenderer.running {
            Text("Beneath").sheet(isPresented: State(wrappedValue: true).projectedValue) {
                VStack { Text("A short note"); Button("Done") }.padding(24)
            }
        }
        let dialog = "document.querySelector('dialog.stateui-sheet[open]')"
        host.settle { (try? WebBrowser.number("\(dialog) ? 1 : 0", on: 0)) == 1 }
        let window = try XCTUnwrap(WebBrowser.evaluate("innerWidth + ',' + innerHeight", on: 0))
            .split(separator: ",").compactMap { Double($0) }
        let fitted = try XCTUnwrap(WebBrowser.evaluate(
            "(() => { const r = \(dialog).getBoundingClientRect(); return r.width + ',' + r.height; })()", on: 0))
            .split(separator: ",").compactMap { Double($0) }
        XCTAssertLessThan(fitted[0], min(560, window[0] - 32), "as wide as its page")
        XCTAssertLessThan(fitted[1], 300, "as tall as its page")
        XCTAssertEqual(try WebBrowser.evaluate("getComputedStyle(\(dialog)).display", on: 0), "flex", "a column")

        let stacked = WebRenderer.running {
            Text("Beneath").sheet(isPresented: State(wrappedValue: true).projectedValue) {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) { Text("Root") } destination: { _ in Text("Next") }
            }
        }
        stacked.settle { (try? WebBrowser.number("\(dialog) ? 1 : 0", on: 0)) == 1 }
        let standard = try XCTUnwrap(WebBrowser.evaluate(
            "(() => { const r = \(dialog).getBoundingClientRect(); return r.width + ',' + r.height; })()", on: 0))
            .split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(standard, [min(560, window[0] - 32), min(640, window[1] - 64)], "the standard size")
    }

    /// A phone's status bar and home indicator stand over the window: its bar reaches under the top, its words clear
    /// of it, and a page's content stands clear of the bottom, or under it where the content says so.
    func testAPageStandsClearOfWhatStandsOverTheWindow() throws {
        WebBrowser.ask([("safeTop", .number(47)), ("safeBottom", .number(34))])
        defer { WebBrowser.ask([("safeTop", .number(0)), ("safeBottom", .number(0))]) }
        let under = State(wrappedValue: false)
        let host = WebRenderer.running {
            ZStack {}.ignoresSafeArea(under.wrappedValue ? .all : .none).id("content")
        }
        let content = { (host.runtime.tree.root?.first(id: .manual("content"))?.native as? WebElement)?.view?.node }
        host.settle { content() != nil }
        let node = try XCTUnwrap(content())
        let bottom: () throws -> Double? = { try WebBrowser.number("e.getBoundingClientRect().bottom", on: node) }
        let window = try XCTUnwrap(WebBrowser.number("innerHeight", on: 0))
        let bar = try XCTUnwrap(WebBrowser.number(
            "parseFloat(getComputedStyle(document.querySelector('.stateui-window > .stateui-bar')).paddingTop)", on: 0))
        XCTAssertEqual(bar, 47, "the bar's words clear of the notch")
        XCTAssertEqual(try XCTUnwrap(bottom()), window - 34, accuracy: 0.5, "clear of the home indicator")

        under.wrappedValue = true
        host.settle { (try? bottom()) == window }
        XCTAssertEqual(try XCTUnwrap(bottom()), window, accuracy: 0.5, "under it")
    }

    /// The window's bar is a material over the top of its room: a page's content stands below it, and a page's rows
    /// let under it scroll under it, the first clear of it.
    func testAPagesRowsScrollUnderTheWindowsBar() throws {
        let under = State(wrappedValue: false)
        let host = WebRenderer.running {
            Grid { ScrollView { Text("rows").height(2000) }.id("rows") }
                .ignoresSafeArea(under.wrappedValue ? .all : .none)
        }
        let rows = { (host.runtime.tree.root?.first(id: .manual("rows"))?.native as? WebElement)?.view?.node }
        host.settle { rows() != nil }
        let node = try XCTUnwrap(rows())
        let bar = try XCTUnwrap(WebBrowser.number(
            "document.querySelector('.stateui-window > .stateui-bar').getBoundingClientRect().height", on: 0))
        let top: () throws -> Double? = { try WebBrowser.number("e.getBoundingClientRect().top", on: node) }
        XCTAssertEqual(try XCTUnwrap(top()), bar, accuracy: 0.5, "below the bar")
        let window = try XCTUnwrap(WebBrowser.number("innerWidth", on: 0))
        let barWidth = try XCTUnwrap(WebBrowser.number(
            "document.querySelector('.stateui-window > .stateui-bar').getBoundingClientRect().width", on: 0))
        let rowsWidth = try XCTUnwrap(WebBrowser.number("e.getBoundingClientRect().width", on: node))
        XCTAssertEqual(barWidth, window, accuracy: 0.5, "the bar across the window")
        XCTAssertEqual(rowsWidth, window, accuracy: 0.5, "the rows across it under the bar")

        under.wrappedValue = true
        host.settle { (try? top()) == 0 }
        XCTAssertEqual(try XCTUnwrap(top()), 0, accuracy: 0.5, "under it")
        let clear = try XCTUnwrap(WebBrowser.number("parseFloat(getComputedStyle(e).paddingTop)", on: node))
        XCTAssertEqual(clear, bar, accuracy: 0.5, "its first row clear of it")
    }

    /// On a window as narrow as a phone the bar's parts overlap nothing and stand within it: the first actions in
    /// reading order stay on the bar, and those that do not fit stand behind More.
    func testABarOnANarrowWindowOverlapsNothing() throws {
        WebBrowser.ask([("density", .number(3)), ("width", .number(430))])
        defer { WebBrowser.ask([("density", .number(1))]) }
        let host = WebRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root").title("Toolbar and menus").toolbar {
                    ToolbarGroup {
                        ToolbarButton("Save")
                        ToolbarButton("Add")
                    }
                    ToolbarButton("Sort")
                    ToolbarButton("Favorite")
                    ToolbarGroup {
                        ToolbarButton("Inspector")
                        ToolbarButton("Home")
                    }
                    ToolbarButton("Share")
                    ToolbarButton("Duplicate")
                }
            } destination: { _ in Text("Pushed") }
        }
        // The bar's buttons and title as they stand, a crossing counted for each part beyond the bar's edges or
        // over the part before it.
        let crossings = """
            (() => {
              const bar = document.querySelector('.stateui-window > .stateui-bar');
              const seen = (e) => { const r = e.getBoundingClientRect(); return r.width > 0 && !e.closest('[hidden]')
                && getComputedStyle(e).visibility !== 'hidden'; };
              const parts = [...bar.querySelectorAll('button, .stateui-bar-title')]
                .filter((e) => seen(e) && !e.parentElement.closest('button')).map((e) => e.getBoundingClientRect())
                .sort((a, b) => a.left - b.left);
              const box = bar.getBoundingClientRect();
              return parts.filter((r, i) => r.left < box.left - 0.5 || r.right > box.right + 0.5
                || (i > 0 && r.left < parts[i - 1].right - 0.5)).length;
            })()
            """
        let words = "document.querySelector('.stateui-window > .stateui-bar').innerText"
        host.settle { (try? WebBrowser.evaluate(words, on: 0))?.contains("Save") == true }
        host.settle { (try? WebBrowser.number(crossings, on: 0)) == 0 }

        XCTAssertEqual(try WebBrowser.number(crossings, on: 0), 0, "nothing overlaps or leaves the bar")
        let shown = """
            [...document.querySelectorAll('.stateui-window > .stateui-bar .stateui-bar-group button')]
              .filter((b) => !b.closest('[hidden]')).map((b) => b.innerText.trim()).join(',')
            """
        let standing = try XCTUnwrap(WebBrowser.evaluate(shown, on: 0)).split(separator: ",").map(String.init)
        XCTAssertEqual(standing.first, "Save", "the first action stays on the bar")
        let left = ["Save", "Add", "Sort", "Favorite", "Inspector", "Home", "Share", "Duplicate"]
            .filter { !standing.contains($0) }
        XCTAssertEqual(left.last, "Duplicate", "a phone's bar has no room for all eight: the last leaves first")
        try WebBrowser.run("document.querySelector('.stateui-window > .stateui-bar > .stateui-bar-actions > button[aria-label=More]').click()")
        let behind = try XCTUnwrap(WebBrowser.evaluate(
            "[...document.querySelectorAll('.stateui-menu')].filter((m) => m.matches(':popover-open'))"
                + ".map((m) => m.innerText).join('\\n')", on: 0))
        for action in left { XCTAssertTrue(behind.contains(action), "\(action) behind More: \(behind)") }
    }

    /// A bar holds still once it stands: on a phone beside a hidden sidebar, its actions crowding its title, it
    /// stands one way frame after frame - what it tries in deciding moves nothing it measures next.
    func testACrowdedBarHoldsStill() throws {
        WebBrowser.ask([("density", .number(3)), ("width", .number(430))])
        defer { WebBrowser.ask([("density", .number(1))]) }
        let host = WebRenderer.running {
            SplitView(State(wrappedValue: false).projectedValue) {
                Text("Samples").title("Gallery")
            } detail: {
                Text("Shortcut").title("Keyboard shortcut").toolbar {
                    ToolbarGroup {
                        ToolbarButton("Mark")
                        ToolbarButton("Code")
                    }
                    ToolbarButton("Share")
                }
            }
        }
        let standing = """
            (() => {
              const bar = document.querySelector('.stateui-window > .stateui-bar');
              const shown = [...bar.querySelectorAll('.stateui-bar-group')].filter((g) => !g.closest('[hidden]'));
              return (bar.hasAttribute('data-crowded') ? 'crowded, ' : 'centered, ') + shown.length + ' groups';
            })()
            """
        host.settle { (try? WebBrowser.evaluate(standing, on: 0)) != nil }
        var seen: [String] = []
        for _ in 0..<40 {
            WebBrowser.pause()
            if let now = try WebBrowser.evaluate(standing, on: 0), now != seen.last { seen.append(now) }
        }

        XCTAssertEqual(seen.count, 1, "one standing, frame after frame: \(seen)")
    }

    /// A held button selects no words: a finger held on a button - the page's, the bar's, a tab's - presses it, and
    /// the browser's selection never takes its words.
    func testAHeldButtonSelectsNoWords() throws {
        let host = WebRenderer.running {
            TabView([0, 1]) { tab in
                VStack { Button("Reset") }
                    .title("Tab \(tab)")
                    .toolbar { ToolbarButton("Share") }
            }
        }
        let count = "document.querySelectorAll('.stateui-window button').length"
        host.settle { (try? WebBrowser.number(count, on: 0)) ?? 0 >= 4 }
        let selectable = """
            [...document.querySelectorAll('.stateui-window button')]
              .filter((b) => getComputedStyle(b).userSelect !== 'none')
              .map((b) => b.innerText.trim() || b.getAttribute('aria-label')).join(',')
            """

        XCTAssertEqual(try WebBrowser.evaluate(selectable, on: 0) ?? "", "", "buttons whose words a hold selects")
    }

    /// On a touch screen a button the user tapped is not left lit: what lights a button under the pointer waits for a
    /// pointer that hovers, which a finger is not - the browser holds the tapped one hovered till the next tap.
    func testATappedButtonIsNotLeftLitOnATouchScreen() throws {
        WebBrowser.ask([("hover", .words("none"))])
        defer { WebBrowser.ask([("hover", .words(""))]) }
        let host = WebRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root").title("Notes").toolbar { ToolbarButton("Save") }
            } destination: { _ in Text("Pushed") }
        }
        let save = "[...document.querySelectorAll('.stateui-window > .stateui-bar button')]"
            + ".find((b) => b.innerText.trim() === 'Save')"
        host.settle { (try? WebBrowser.truth("!!\(save)", on: 0)) == true }
        // A question an earlier test of this page left open would stand over the bar, under the finger; the button's
        // fade is taken out, so its color reads at once.
        try WebBrowser.run("document.querySelectorAll('dialog[open]').forEach((d) => d.close())")
        try WebBrowser.run("\(save).style.transition = 'none'")
        let ground = try XCTUnwrap(WebBrowser.evaluate("getComputedStyle(\(save)).backgroundColor", on: 0))
        let middle = try XCTUnwrap(WebBrowser.evaluate(
            "(() => { const r = \(save).getBoundingClientRect(); return (r.left + r.width / 2) + ',' + (r.top + r.height / 2); })()",
            on: 0)).split(separator: ",").compactMap { Double($0) }

        WebBrowser.ask([("touch", .words("touchStart")), ("points", .points([Point(x: middle[0], y: middle[1])]))])
        WebBrowser.ask([("touch", .words("touchEnd")), ("points", .points([]))])
        let lit = { try WebBrowser.evaluate("getComputedStyle(\(save)).backgroundColor", on: 0) }
        // The press's own light goes as the finger lifts; what stays is the browser's hover.
        host.settle { (try? WebBrowser.truth("\(save).matches(':active')", on: 0)) == false }

        XCTAssertTrue(try WebBrowser.truth("\(save).matches(':hover')", on: 0), "the browser holds the tapped button hovered")
        XCTAssertEqual(try lit(), ground, "and leaves it unlit")
    }

    /// A grouped button lights under a pointer that hovers, whatever the bar's style: its group's ground at rest, its
    /// own light over it - as a button standing alone lights.
    func testAGroupedButtonLightsUnderThePointerInEveryStyle() throws {
        let style = State(wrappedValue: ToolbarStyle.glass)
        let host = WebRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root").title("Notes").toolbar {
                    ToolbarGroup {
                        ToolbarButton("Add")
                        ToolbarButton("Edit")
                    }
                }
            } destination: { _ in Text("Pushed") }
            .toolbarStyle(style.wrappedValue)
        }
        let add = "[...document.querySelectorAll('.stateui-window > .stateui-bar .stateui-bar-group button')]"
            + ".find((b) => b.innerText.trim() === 'Add')"
        let bar = "document.querySelector('.stateui-window > .stateui-bar')"
        host.settle { (try? WebBrowser.truth("!!\(add)", on: 0)) == true }
        try WebBrowser.run("document.querySelectorAll('dialog[open]').forEach((d) => d.close())")
        let middle = try XCTUnwrap(WebBrowser.evaluate(
            "(() => { const r = \(add).getBoundingClientRect(); return (r.left + r.width / 2) + ',' + (r.top + r.height / 2); })()",
            on: 0)).split(separator: ",").compactMap { Double($0) }
        let ground = { try WebBrowser.evaluate("(\(add).style.transition = 'none', getComputedStyle(\(add)).backgroundColor)", on: 0) }
        let move = { (x: Double, y: Double) -> Void in
            WebBrowser.ask([
                ("mouse", .words("mouseMoved")), ("x", .number(x)), ("y", .number(y)), ("count", .number(1)),
                ("held", .truth(false)), ("deltaY", .number(0)), ("modifiers", .number(0)), ("button", .words("left")),
            ])
        }
        var lit: [String: String] = [:]
        for look in [ToolbarStyle.glass, .plain, .rounded] {
            style.wrappedValue = look
            host.settle { (try? WebBrowser.evaluate("\(bar).dataset.toolbarStyle ?? 'glass'", on: 0)) == "\(look)" }
            move(0, 0)
            let rest = try ground()
            move(middle[0], middle[1])
            host.settle { (try? WebBrowser.truth("\(add).matches(':hover')", on: 0)) == true }
            lit["\(look)"] = try ground() != rest ? "lit" : "unlit"
        }

        XCTAssertEqual(lit, ["glass": "lit", "plain": "lit", "rounded": "lit"])
    }

    /// A button on a bar that cannot be chosen lights under no pointer and no press, whatever the bar's style - as a
    /// menu's entry that cannot be chosen.
    func testADisabledBarButtonLightsUnderNoPointer() throws {
        let style = State(wrappedValue: ToolbarStyle.glass)
        let host = WebRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root").title("Notes").toolbar {
                    ToolbarGroup {
                        ToolbarButton("Add")
                        ToolbarButton("Edit").isEnabled(false)
                    }
                }
            } destination: { _ in Text("Pushed") }
            .toolbarStyle(style.wrappedValue)
        }
        let edit = "[...document.querySelectorAll('.stateui-window > .stateui-bar .stateui-bar-group button')]"
            + ".find((b) => b.innerText.trim() === 'Edit')"
        let bar = "document.querySelector('.stateui-window > .stateui-bar')"
        host.settle { (try? WebBrowser.truth("!!\(edit)", on: 0)) == true }
        try WebBrowser.run("document.querySelectorAll('dialog[open]').forEach((d) => d.close())")
        let middle = try XCTUnwrap(WebBrowser.evaluate(
            "(() => { const r = \(edit).getBoundingClientRect(); return (r.left + r.width / 2) + ',' + (r.top + r.height / 2); })()",
            on: 0)).split(separator: ",").compactMap { Double($0) }
        let ground = { try WebBrowser.evaluate("(\(edit).style.transition = 'none', getComputedStyle(\(edit)).backgroundColor)", on: 0) }
        let mouse = { (kind: String, x: Double, y: Double) -> Void in
            WebBrowser.ask([
                ("mouse", .words(kind)), ("x", .number(x)), ("y", .number(y)), ("count", .number(1)),
                ("held", .truth(kind == "mousePressed")), ("deltaY", .number(0)), ("modifiers", .number(0)),
                ("button", .words("left")),
            ])
        }
        var lit: [String: String] = [:]
        for look in [ToolbarStyle.glass, .plain, .rounded] {
            style.wrappedValue = look
            host.settle { (try? WebBrowser.evaluate("\(bar).dataset.toolbarStyle ?? 'glass'", on: 0)) == "\(look)" }
            mouse("mouseMoved", 0, 0)
            let rest = try ground()
            mouse("mouseMoved", middle[0], middle[1])
            host.settle { (try? WebBrowser.truth("\(edit).matches(':hover')", on: 0)) == true }
            let over = try ground()
            mouse("mousePressed", middle[0], middle[1])
            let pressed = try ground()
            mouse("mouseReleased", middle[0], middle[1])
            lit["\(look)"] = over == rest && pressed == rest ? "unlit" : "lit"
        }

        XCTAssertEqual(lit, ["glass": "unlit", "plain": "unlit", "rounded": "unlit"])
    }

    /// A setting standing on keeps its tint under the pointer on glass: the light a pointer brings a bar's button
    /// gives way to the tint saying it is on.
    func testASettingStandingOnKeepsItsTintUnderThePointer() throws {
        let host = WebRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root").title("Notes").toolbar { ToolbarToggle("Pin", isOn: true) }
            } destination: { _ in Text("Pushed") }
            .toolbarStyle(.glass)
        }
        let pin = "[...document.querySelectorAll('.stateui-window > .stateui-bar button')]"
            + ".find((b) => b.innerText.trim() === 'Pin')"
        host.settle { (try? WebBrowser.truth("!!\(pin) && \(pin).getAttribute('aria-pressed') === 'true'", on: 0)) == true }
        try WebBrowser.run("document.querySelectorAll('dialog[open]').forEach((d) => d.close())")
        let middle = try XCTUnwrap(WebBrowser.evaluate(
            "(() => { const r = \(pin).getBoundingClientRect(); return (r.left + r.width / 2) + ',' + (r.top + r.height / 2); })()",
            on: 0)).split(separator: ",").compactMap { Double($0) }
        let ground = { try WebBrowser.evaluate("(\(pin).style.transition = 'none', getComputedStyle(\(pin)).backgroundColor)", on: 0) }
        let move = { (x: Double, y: Double) -> Void in
            WebBrowser.ask([
                ("mouse", .words("mouseMoved")), ("x", .number(x)), ("y", .number(y)), ("count", .number(1)),
                ("held", .truth(false)), ("deltaY", .number(0)), ("modifiers", .number(0)), ("button", .words("left")),
            ])
        }
        move(0, 0)
        let tint = try ground()
        move(middle[0], middle[1])
        host.settle { (try? WebBrowser.truth("\(pin).matches(':hover')", on: 0)) == true }

        XCTAssertEqual(try ground(), tint)
    }

    /// A bar's button saying the room inside it is as tall as its words and that room, as a control is - lower than
    /// the bar's own buttons stand where it says none.
    func testABarButtonSayingItsRoomIsAsTallAsItsWordsAndRoom() throws {
        let host = WebRenderer.running {
            NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                Text("Root").title("Notes").toolbar {
                    ToolbarButton("Save").padding(horizontal: 10, vertical: 4)
                    ToolbarButton("Sort")
                }
            } destination: { _ in Text("Pushed") }
        }
        let button = { (words: String) in
            "[...document.querySelectorAll('.stateui-window > .stateui-bar button')].find((b) => b.innerText.trim() === '\(words)')"
        }
        host.settle { (try? WebBrowser.truth("!!\(button("Save")) && !!\(button("Sort"))", on: 0)) == true }
        let height = { (words: String) in try WebBrowser.number("\(button(words)).getBoundingClientRect().height", on: 0) ?? 0 }
        let words = try WebBrowser.number("\(button("Save")).querySelector('span').getBoundingClientRect().height", on: 0) ?? 0

        XCTAssertEqual(try height("Save"), words + 8, accuracy: 1, "its words and the room it says")
        XCTAssertEqual(try height("Sort"), 42, accuracy: 0.5, "the bar's own height where it says none")
    }

    /// The application's name over a sidebar beside the page stands at the start of its part, in line with the
    /// content of the rows under it - 20 from the edge - the toggle at the part's end.
    func testTheApplicationsNameStandsAtTheStartOverTheSidebar() throws {
        let host = WebRenderer.running {
            SplitView(State(wrappedValue: true).projectedValue) {
                Text("Samples").title("Gallery")
            } detail: {
                Text("Detail").title("Page")
            }
        }
        let bar = "document.querySelector('.stateui-window > .stateui-bar')"
        let name = "\(bar).querySelector('.stateui-bar-name')"
        let side = "\(bar).querySelector('.stateui-bar-side')"
        host.settle {
            (try? WebBrowser.truth("\(bar).dataset.sidebar === 'shown' && \(name).textContent === 'Gallery'", on: 0)) == true
        }
        let start = try XCTUnwrap(WebBrowser.number(
            "\(name).getBoundingClientRect().left - \(side).getBoundingClientRect().left", on: 0))

        XCTAssertEqual(start, 20, accuracy: 1, "in line with a row's content")
    }

    /// A clear bar paints nothing and softens what scrolls under it: a blur under its words, fading out toward its
    /// bottom edge. A bar of a color blurs behind its whole paint instead.
    func testAClearBarSoftensWhatScrollsUnderIt() throws {
        let clear = State(wrappedValue: true)
        let host = WebRenderer.running {
            TabView([0]) { tab in Text("Tab \(tab)").title("Tab \(tab)") }
                .title("Clear")
                .barBackground(clear.wrappedValue ? .transparent : .white)
        }
        let edge = { (property: String) in
            try WebBrowser.evaluate(
                "getComputedStyle(document.querySelector('.stateui-window > .stateui-bar'), '::before').\(property)",
                on: 0)
        }
        host.settle { (try? self.look(".stateui-window > .stateui-bar", "backgroundColor")) == "rgba(0, 0, 0, 0)" }

        XCTAssertEqual(try edge("backdropFilter")?.hasPrefix("blur("), true, "a blur")
        XCTAssertEqual(try edge("maskImage")?.hasPrefix("linear-gradient("), true, "fading out")

        clear.wrappedValue = false
        host.settle { (try? self.look(".stateui-window > .stateui-bar", "backgroundColor")) == "rgb(255, 255, 255)" }
        XCTAssertEqual(try edge("backdropFilter"), "none", "a bar of a color")
    }

    func testAControlOverEveryPageWearsTheStylesheet() throws {
        let host = WebRenderer.running {
            Text("Beneath").overlays { VStack { Switch(true); Button("Over") } }
        }
        host.settle { (try? WebBrowser.number("document.querySelectorAll('.stateui-overlays input').length", on: 0)) == 1 }

        XCTAssertEqual(try look(".stateui-overlays input.stateui-switch", "appearance"), "none", "the page's switch")
        XCTAssertEqual(try look(".stateui-overlays button", "touchAction"), "manipulation", "a tap at once")
    }

    /// Where the user asks for less motion, nothing the stylesheet moves once - a sheet rising, its shade, a
    /// question, a menu, a page arriving, a drawer, a switch's knob, a bar's value, the loading screen fading - moves:
    /// each part it animates, or moves by a transition, stands in the less-motion rules.
    func testLessMotionStillsEveryPartTheStylesheetMoves() throws {
        _ = WebRenderer.running { Text("Still") }
        let moving = try WebBrowser.evaluate("""
            (() => {
              const rules = [];
              const walk = (list, still) => {
                for (const r of list) {
                  if (r.cssRules && r.media) walk(r.cssRules, still || r.media.mediaText.includes("prefers-reduced-motion"));
                  else if (r.style) rules.push({ r, still });
                }
              };
              for (const s of document.styleSheets) { try { walk(s.cssRules, false); } catch {} }
              const selectors = (text) => {
                const out = []; let depth = 0, from = 0;
                for (let i = 0; i < text.length; i++) {
                  if ("([".includes(text[i])) depth++;
                  else if (")]".includes(text[i])) depth--;
                  else if (text[i] === "," && depth === 0) { out.push(text.slice(from, i).trim()); from = i + 1; }
                }
                return [...out, text.slice(from).trim()];
              };
              const compounds = (selector) => {
                const out = []; let depth = 0, from = 0;
                for (let i = 0; i < selector.length; i++) {
                  if ("([".includes(selector[i])) depth++;
                  else if (")]".includes(selector[i])) depth--;
                  else if (depth === 0 && " >+~".includes(selector[i])) { out.push(selector.slice(from, i)); from = i + 1; }
                }
                return [...out, selector.slice(from)].filter(c => c !== "");
              };
              const tokens = (compound) => {
                const at = compound.indexOf("::");
                const body = at < 0 ? compound : compound.slice(0, at);
                return { pseudo: at < 0 ? "" : compound.slice(at), tag: (body.match(/^[a-z]+/) ?? [""])[0],
                         marks: [...(body.match(/\\.[a-z-]+/g) ?? []), ...(body.match(/\\[[^\\]]+\\]/g) ?? [])] };
              };
              const covers = (still, part) => {
                const [s, p] = [compounds(still), compounds(part)];
                if (s[s.length - 1] === "*") return tokens(s[s.length - 2] ?? "").marks.every(m => part.includes(m));
                const [a, b] = [tokens(s[s.length - 1]), tokens(p[p.length - 1])];
                return (a.tag !== "" || a.marks.length > 0) && a.pseudo === b.pseudo && (a.tag === "" || a.tag === b.tag)
                  && a.marks.every(m => b.marks.includes(m));
              };
              const glides = ["transform", "translate", "width", "height", "opacity", "padding", "margin", "inset",
                              "grid-template-columns", "top", "left", "right", "bottom", "--"];
              const moves = (style) => {
                const transition = style.transitionProperty || style.getPropertyValue("transition");
                return (style.animationName && style.animationName !== "none" && style.animationIterationCount !== "infinite")
                  || transition.split(",").some(t => glides.some(g => t.trim().startsWith(g)));
              };
              const stilled = rules.filter(x => x.still && x.r.style.animationName === "none"
                  && x.r.style.transitionProperty === "none").flatMap(x => selectors(x.r.selectorText));
              return rules.filter(x => !x.still && moves(x.r.style))
                .flatMap(x => selectors(x.r.selectorText))
                .filter(part => !stilled.some(still => covers(still, part)))
                .join(" | ");
            })()
            """, on: 0)

        XCTAssertEqual(moving, "", "these move where the user asks for less motion")
    }

    /// The sidebar stands beside the detail from the split view's breakpoint on, and over it below: the stylesheet's
    /// drawer stops short of the width the host layer's rule shows the sidebar at, and its bar starts there.
    func testTheDrawerStopsWhereTheSidebarStandsBeside() throws {
        _ = WebRenderer.running { Text("Wide") }
        let widths = try WebBrowser.evaluate("""
            [...document.styleSheets].flatMap(s => { try { return [...s.cssRules]; } catch { return []; } })
              .filter(r => r.media && /(max|min)-width/.test(r.media.mediaText) && /stateui-split|data-sidebar/.test(r.cssText))
              .map(r => r.media.mediaText).join(" | ")
            """, on: 0) ?? ""
        let breakpoint = WebSplitView.breakpoint
        let most = widths.matches(of: /max-width: ([0-9.]+)px/).compactMap { Double($0.1) }
        let least = widths.matches(of: /min-width: ([0-9.]+)px/).compactMap { Double($0.1) }

        XCTAssertFalse(most.isEmpty || least.isEmpty, widths)
        XCTAssertTrue(most.allSatisfy { $0 < breakpoint && $0 > breakpoint - 1 }, "the drawer reaches the breakpoint: \(widths)")
        XCTAssertTrue(least.allSatisfy { $0 == breakpoint }, "the sidebar beside starts past it: \(widths)")
    }

    /// Words on a band the tree paints and gives no color for them stand dark on a light band, whatever the page's
    /// own scheme - the window's bar's and a strip of tabs' alike, as the host layer's rule says.
    func testWordsOnALightBandStandDark() throws {
        let host = WebRenderer.running {
            TabView([0, 1]) { tab in Text("Tab \(tab)").title("Tab \(tab)") }
                .title("Light")
                .barBackground(.white)
        }
        host.settle { (try? self.look(".stateui-tab-strip > button", "color")) != nil }

        XCTAssertEqual(try look(".stateui-window .stateui-bar", "color"), "rgb(0, 0, 0)", "the window's bar")
        XCTAssertEqual(
            try look(".stateui-tab-strip > button:not([aria-selected=true])", "color"), "rgb(0, 0, 0)",
            "a tab not chosen")
    }

    /// The page itself holds still under a finger: the window stands over the browser's, and a finger pulling past a
    /// view that does not scroll would pull the browser's page after it - bounced back, it takes the next tap to stop.
    func testThePageItselfNeverBounces() throws {
        let host = WebRenderer.running { Text("Still") }
        host.settle { (try? self.look(".stateui-window", "position")) != nil }

        XCTAssertEqual(try look("html", "overscrollBehaviorY"), "none", "the document")
        XCTAssertEqual(try look("body", "overscrollBehaviorY"), "none", "the body")
    }

    /// A bar's button moving from the part over the sidebar to the detail's as the sidebar hides slides there from
    /// where it stood, as the sidebar slides.
    func testAButtonMovingBetweenTheBarsPartsSlidesThere() throws {
        let shows = State(wrappedValue: true)
        let host = WebRenderer.running {
            SplitView(shows.projectedValue) {
                Text("Folders").title("Library")
            } detail: {
                Text("Books").title("All books")
            }
            .toolbar { ToolbarButton("Add").placement(.sidebar) }
        }
        let found = { (part: String) in
            (try? WebBrowser.truth("!!document.querySelector('\(part) .stateui-bar-group button')", on: 0)) == true
        }
        host.settle { found(".stateui-bar-side") }
        XCTAssertTrue(found(".stateui-bar-side"), "over the sidebar")

        shows.wrappedValue = false
        host.settle { found(".stateui-bar-start") }
        let sliding = "document.querySelector('.stateui-bar-start .stateui-bar-group button').getAnimations().length"
        XCTAssertEqual(try WebBrowser.number(sliding, on: 0), 1, "at the detail's start, sliding there")
    }

    /// A bar's columns move as its split view's sidebar does: where the sidebar first stands they stand at once, and
    /// as the user hides it the widths of the bar's first and last columns move with it, and nothing else of them.
    func testABarsColumnsMoveAsTheSidebarDoes() throws {
        let shows = State(wrappedValue: true)
        let host = WebRenderer.running {
            SplitView(shows.projectedValue) {
                Text("Folders").title("Library")
            } detail: {
                Text("Books").title("All books")
            }
        }
        let bar = "document.querySelector('.stateui-window > .stateui-bar')"
        let moving = "\(bar).getAnimations().map((a) => a.transitionProperty).sort().join(',')"
        let sidebar = { try? WebBrowser.evaluate("\(bar)?.dataset.sidebar", on: 0) }
        host.settle { sidebar() == "shown" }
        XCTAssertEqual(try WebBrowser.evaluate(moving, on: 0) ?? "", "", "where the sidebar first stands, at once")

        shows.wrappedValue = false
        host.settle { sidebar() == "hidden" }
        XCTAssertEqual(try WebBrowser.evaluate(moving, on: 0), "--stateui-bar-first,--stateui-bar-last", "as it hides")
    }

    /// One computed style of the first element `selector` finds on the page.
    private func look(_ selector: String, _ property: String) throws -> String? {
        try WebBrowser.evaluate("getComputedStyle(document.querySelector('\(selector)')).\(property)", on: 0)
    }
}

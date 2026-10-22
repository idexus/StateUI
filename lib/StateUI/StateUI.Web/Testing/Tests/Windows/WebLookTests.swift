// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A control wears the page's stylesheet wherever it stands - in the window's room, on a sheet, over every page - and
/// takes a tap at once there. The browser draws, so the suite runs it in a browser (`test-web.sh --browser`).
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
    /// go, at the dialog's standard size.
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
            ZStack {}.avoidsSafeArea(under.wrappedValue ? .none : .container).id("content")
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
                .avoidsSafeArea(under.wrappedValue ? .none : .container)
        }
        let rows = { (host.runtime.tree.root?.first(id: .manual("rows"))?.native as? WebElement)?.view?.node }
        host.settle { rows() != nil }
        let node = try XCTUnwrap(rows())
        let bar = try XCTUnwrap(WebBrowser.number(
            "document.querySelector('.stateui-window > .stateui-bar').getBoundingClientRect().height", on: 0))
        let top: () throws -> Double? = { try WebBrowser.number("e.getBoundingClientRect().top", on: node) }
        XCTAssertEqual(try XCTUnwrap(top()), bar, accuracy: 0.5, "below the bar")

        under.wrappedValue = true
        host.settle { (try? top()) == 0 }
        XCTAssertEqual(try XCTUnwrap(top()), 0, accuracy: 0.5, "under it")
        let clear = try XCTUnwrap(WebBrowser.number("parseFloat(getComputedStyle(e).paddingTop)", on: node))
        XCTAssertEqual(clear, bar, accuracy: 0.5, "its first row clear of it")
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
                              "grid-template-columns", "top", "left", "right", "bottom"];
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
                .barBackgroundColor(.white)
        }
        host.settle { (try? self.look(".stateui-tab-strip > button", "color")) != nil }

        XCTAssertEqual(try look(".stateui-window .stateui-bar", "color"), "rgb(0, 0, 0)", "the window's bar")
        XCTAssertEqual(
            try look(".stateui-tab-strip > button:not([aria-selected=true])", "color"), "rgb(0, 0, 0)",
            "a tab not chosen")
    }

    /// One computed style of the first element `selector` finds on the page.
    private func look(_ selector: String, _ property: String) throws -> String? {
        try WebBrowser.evaluate("getComputedStyle(document.querySelector('\(selector)')).\(property)", on: 0)
    }
}

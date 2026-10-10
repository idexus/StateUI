// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
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
            ModalStack(State(wrappedValue: [1]).projectedValue) {
                Text("Beneath")
            } destination: { _ in
                VStack { Switch(true); Button("Done") }
            }
        }
        host.settle { (try? WebBrowser.number("document.querySelectorAll('dialog[open]').length", on: 0)) == 1 }

        XCTAssertEqual(try look("dialog[open] input.stateui-switch", "appearance"), "none", "the page's switch")
        XCTAssertEqual(try look("dialog[open] .stateui-sheet-room button", "touchAction"), "manipulation", "a tap at once")
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
    /// question, a menu, a page arriving - moves: each part it animates stands in the less-motion rules.
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
              const last = (selector) => selector.split(/\\s*[>+~ ]\\s*/).pop();
              const stilled = rules.filter(x => x.still && x.r.style.animationName === "none")
                .flatMap(x => x.r.selectorText.split(",").map(t => last(t.trim())));
              return rules.filter(x => !x.still && x.r.style.animationName && x.r.style.animationName !== "none"
                  && x.r.style.animationIterationCount !== "infinite")
                .flatMap(x => x.r.selectorText.split(",").map(t => last(t.trim())))
                .filter(part => {
                  const pseudo = part.includes("::") ? part.slice(part.indexOf("::")) : "";
                  const named = part.match(/\\.stateui-[a-z-]+/g) ?? [];
                  return !named.every(c => stilled.some(s => s.includes(c) && (pseudo === "" || s.includes(pseudo))));
                })
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

    /// Words on a band the tree paints and gives no colour for them stand dark on a light band, whatever the page's
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

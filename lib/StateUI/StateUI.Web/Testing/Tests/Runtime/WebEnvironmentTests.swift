// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// What the page tells the core it stands on, as the browser has it. The browser says, so the suite runs it in one
/// (`test-web.sh --browser`).
@MainActor
final class WebEnvironmentTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// THE PAGE TELLS THE USER'S LOCALE: the language the user put first, its region, the zone, the clock, the week
    /// and the measures of that language's country, and every language the user reads.
    func testThePageTellsTheUsersLocale() throws {
        defer { WebBrowser.ask([("languages", .words(""))]) }

        let polish = try locale(languages: "pl-PL,en-US", zone: "Europe/Warsaw")
        XCTAssertEqual(polish.language, "pl")
        XCTAssertEqual(polish.region, "PL")
        XCTAssertEqual(polish.name, "pl-PL")
        XCTAssertEqual(polish.timeZone, "Europe/Warsaw")
        XCTAssertTrue(polish.uses24HourClock)
        XCTAssertEqual(polish.firstDayOfWeek, .monday)
        XCTAssertTrue(polish.isMetric)
        XCTAssertEqual(polish.languages.map(\.identifier), ["pl-PL", "en-US"])

        let american = try locale(languages: "en-US", zone: "America/New_York")
        XCTAssertEqual(american.language, "en")
        XCTAssertEqual(american.region, "US")
        XCTAssertEqual(american.timeZone, "America/New_York")
        XCTAssertFalse(american.uses24HourClock)
        XCTAssertEqual(american.firstDayOfWeek, .sunday)
        XCTAssertFalse(american.isMetric)
    }

    /// THE CHROME'S OWN BUTTONS SAY THE LIBRARY'S WORDS in the user's language (`ChromeWords`): the sidebar's toggle,
    /// the way back, a sheet's close and the overflow.
    /// What the user asked of motion and contrast is the browser's: its media queries; a page is told of no screen
    /// reader and no scale of the system's words.
    func testThePageTellsWhatTheUserAskedOfMotionAndContrast() throws {
        WebRenderer.shared?.leave()
        HostBoundary.setAccessibilityInfo(HostAccessibilityInfo(
            reducesMotion: true, prefersHigherContrast: true, isScreenReaderOn: true, textScale: 0))
        let host = WebRenderer.running { Text("Shown") }
        host.step()
        defer { host.leave() }
        let settings = StandardEnvironment.device.accessibility

        let still = try WebBrowser.truth("matchMedia('(prefers-reduced-motion: reduce)').matches", on: 0)
        let contrast = try WebBrowser.truth("matchMedia('(prefers-contrast: more)').matches", on: 0)
        XCTAssertEqual(settings.reducesMotion, still)
        XCTAssertEqual(settings.prefersHigherContrast, contrast)
        XCTAssertFalse(settings.isScreenReaderOn)
        XCTAssertEqual(settings.textScale, 1)
    }

    func testTheChromesButtonsSayTheLibrarysWords() throws {
        defer { WebBrowser.ask([("languages", .words(""))]) }
        WebRenderer.shared?.leave()
        WebBrowser.ask([("languages", .words("pl-PL")), ("zone", .words("Europe/Warsaw"))])
        let host = WebRenderer.running { Text("Shown") }
        host.step()
        defer { host.leave() }

        let words = CoreLink().chromeWords
        XCTAssertEqual(words.sidebar, "Pasek boczny", "the user reads Polish")
        let said = try WebBrowser.evaluate(
            "[...document.querySelectorAll('.stateui-bar button[aria-label]')].map((b) => b.getAttribute('aria-label'))",
            on: 0)?.split(separator: "\u{0}").map(String.init) ?? []
        XCTAssertEqual(Set(said), [words.sidebar, words.back, words.close, words.more])
    }

    /// The locale the core holds once a host starts on a page whose user reads `languages` in `zone`.
    private func locale(languages: String, zone: String) throws -> LocaleInfo {
        WebRenderer.shared?.leave()
        WebBrowser.ask([("languages", .words(languages)), ("zone", .words(zone))])
        let host = WebRenderer.running { Text("Shown") }
        host.step()
        defer { host.leave() }
        return StandardEnvironment.locale
    }
}

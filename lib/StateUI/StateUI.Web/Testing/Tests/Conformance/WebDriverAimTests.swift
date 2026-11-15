// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
@testable import StateUIWeb
import XCTest

/// The driver measures an element where the mouse will find it: the mouse reaches the page a moment after the
/// measure, so what an animation of the page's still moves is measured once it has come. A host runs in the page, so
/// the suite runs it in a browser (the stateui tool's `WebSuite.inBrowser`).
@MainActor
final class WebDriverAimTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testAButtonOnASheetStillRisingIsMeasuredWhereItComesToStand() throws {
        let shows = State(wrappedValue: false)
        let driver = WebDriver()
        let tree = driver.start(clock: nil, reducesMotion: false) {
            Text("beneath").sheet(isPresented: shows.projectedValue) {
                Button("Another").onClicked {}.id("another")
            }
        }
        defer { driver.renderer?.finish() }
        shows.wrappedValue = true
        var button: MountedElement?
        for _ in 0..<10 {
            button = tree.root?.first(id: .manual("another"))
            guard button == nil else { break }
            driver.step()
        }
        let node = try driver.view(of: XCTUnwrap(button, "the sheet's button"), .activate).node
        XCTAssertFalse(try WebBrowser.truth("stateui.still(e)", on: node), "the sheet rises as it is shown")

        let measured = try driver.box(of: node)

        try WebBrowser.run("document.getAnimations().forEach((animation) => animation.finish())")
        let stands = try driver.numbers("stateui.box(e)", on: node)
        XCTAssertEqual([measured.x, measured.y], Array(stands.prefix(2)), "measured where the sheet brings it")
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance
@_spi(Host) import StateUIHost
import XCTest

/// A gesture a conformance case performs on the Web lifts at the speed it went, however slowly the machine takes the
/// driver's steps: the case's clock times it, not the page's.
@MainActor
final class WebGesturePaceTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// STEPS A TENTH OF A SECOND APART LIFT AT THE SPEED THEY WENT: two fingers turning and a press dragged, each
    /// step reaching the page 150 ms after the last, as a busy machine takes them.
    func testAGestureTakenSlowlyLiftsAtTheSpeedItWent() {
        WebDriver.pace = 150
        defer { WebDriver.pace = 0 }
        XCTAssertEqual(SlowGestures.cases.map(\.name), SlowGestures.names)
        var failures: [String] = []
        _ = Conformance.run(SlowGestures.self, on: WebDriver(), report: { failures.append($0.message) })
        XCTAssertEqual(failures, [])
    }

    /// A CASE TURNING FINGERS ON THE PAGE'S OWN CLOCK FAILS, SAYING WHY: the speed it reads would be the machine's
    /// pace.
    func testAGestureOnThePagesOwnClockFailsSayingWhy() {
        var failures: [String] = []
        _ = Conformance.run(OwnClock.self, on: WebDriver(), report: { failures.append($0.message) })
        XCTAssertEqual(failures, [
            "Web · turned: rotate goes as fast as the clock says: its case starts on a TestClock, "
                + "not at the machine's pace",
        ])
    }
}

/// The View cases that read how fast a gesture lifts, on a rectangle.
private enum SlowGestures: ConformanceFamily {
    static let name = ViewTests.name
    static let names = [
        "Rectangle.aPanIsHeardAndCarriesItsStateAcross", "Rectangle.twoFingersTurningAreHeardFromTheirStart",
    ]

    static var cases: [ConformanceCase] {
        ViewTests.cases.filter { names.contains($0.name) }
    }
}

/// A case that turns two fingers on the page's own clock.
private enum OwnClock: ConformanceFamily {
    static let name = ViewTests.name

    static var cases: [ConformanceCase] {
        [ConformanceCase("turned", proves: [Covered(ViewContract.rotationUpdated, on: "Rectangle")]) { s in
            s.start { Rectangle().fill(.red).width(100).height(100).id("specimen") }
            try s.perform(.rotate(degrees: 30, at: Point(0.5, 0.5)), on: s.element("specimen"))
        }]
    }
}

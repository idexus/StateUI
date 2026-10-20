// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization
import XCTest
@_spi(Host) @testable import StateUI

/// What the library says when an application hands it something it cannot use.
@MainActor
final class ComplaintsTests: XCTestCase {
    /// An application routes the complaints where it wants them - each said once - and nil sends them back to the
    /// standard output.
    func testAComplaintGoesWhereTheApplicationRoutesIt() {
        let heard = Mutex<[String]>([])
        Complaints.route { words in heard.withLock { $0.append(words) } }
        defer { Complaints.route(to: nil) }

        complain("ComplaintsTests: routed once")
        complain("ComplaintsTests: routed once")

        XCTAssertEqual(heard.withLock { $0 }, ["ComplaintsTests: routed once"])
    }

    /// A complaint the application routes nowhere goes to the host's log; one it routes goes there alone.
    func testAComplaintTheApplicationRoutesNowhereGoesToTheHostsLog() {
        let host = Mutex<[String]>([])
        let application = Mutex<[String]>([])
        Complaints.routeByDefault { words in host.withLock { $0.append(words) } }
        defer { Complaints.routeByDefault(to: nil) }

        complain("ComplaintsTests: to the host's log")
        Complaints.route { words in application.withLock { $0.append(words) } }
        complain("ComplaintsTests: to the application")
        Complaints.route(to: nil)

        XCTAssertEqual(host.withLock { $0 }, ["ComplaintsTests: to the host's log"])
        XCTAssertEqual(application.withLock { $0 }, ["ComplaintsTests: to the application"])
    }

    /// The things said are held to a number, so complaints naming ever new values cannot grow without end: past it,
    /// that is said once, and nothing more.
    func testWhatIsSaidStopsAtItsCap() {
        let heard = Mutex<[String]>([])
        let said = Said(cap: 2)
        said.route { words in heard.withLock { $0.append(words) } }

        for index in 0..<5 { said.say("complaint \(index)") }
        said.say("complaint 0")

        let lines = heard.withLock { $0 }
        XCTAssertEqual(lines.prefix(2), ["complaint 0", "complaint 1"])
        XCTAssertEqual(lines.count, 3, "the two, then one line saying the rest is not said")
        XCTAssertTrue(lines.last?.contains("not said") == true, lines.last ?? "")
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUIHost
import XCTest

/// Where a runtime's time goes, stage by stage, in a process started probed.
@MainActor
final class HostProbeTests: XCTestCase {
    override func tearDown() async throws {
        HostProbe.start(where: DiagnosticText(tallies: false, inspects: false, write: { _ in }))
    }

    /// UNPROBED, A STAGE RUNS AS IT IS: its answer, and nothing kept.
    func testUnprobedAStageRunsAsItIs() {
        HostProbe.start(where: DiagnosticText(tallies: false, inspects: false, write: { _ in }))

        XCTAssertEqual(HostProbe.timed(.render) { 7 }, 7)
        XCTAssertNil(HostProbe.running)
    }

    /// PROBED, EACH STAGE THAT RAN IS ON THE LINE with how many times it ran; one that did not is left out.
    func testProbedEachStageThatRanIsOnTheLine() throws {
        HostProbe.start(where: DiagnosticText(tallies: false, inspects: false, probes: true, write: { _ in }))

        XCTAssertEqual(HostProbe.timed(.render) { 7 }, 7)
        HostProbe.timed(.render) {}
        HostProbe.timed(.cycle) {}

        let line = try XCTUnwrap(HostProbe.running?.line)
        XCTAssertTrue(line.hasPrefix("StateUI stages: render "), line)
        XCTAssertTrue(line.contains("(2x, most "), line)
        XCTAssertTrue(line.contains(" · cycle "), line)
        XCTAssertFalse(line.contains("present"), line)
        XCTAssertTrue(line.hasSuffix("\n"))
    }
}

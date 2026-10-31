// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// What a host's animator says of a state's journey, a test playing the host: the journey it reads off the board,
/// and the report it makes back.
@MainActor
enum HostAnimatorReport {
    /// The binding a host wears `state` by and the journey it reads off the board for it - what the board wrote since
    /// read first, as a host reads it; nil for a state the host carries no journey of.
    static func standing(_ state: Int32) -> (binding: HostStateBinding, journey: HostJourney)? {
        guard let storage = Renderer.shared.storage(of: state), let kind = storage.door else { return nil }

        let binding = HostStateBinding(state: state, mode: .inOut, kind: kind, laneKind: storage.laneKind)
        _ = Renderer.shared.board.dirty()
        return HostBoundary.value(for: binding).flatMap(HostBoundary.journey(from:)).map { (binding, $0) }
    }

    /// `state` as the host's animator leaves a journey that ended: at its destination, standing still.
    static func land(_ state: Int32, file: StaticString = #filePath, line: UInt = #line) {
        guard let (binding, standing) = standing(state) else {
            return XCTFail("the host carries no journey of that state", file: file, line: line)
        }

        let landed = HostJourney(
            value: standing.destination, destination: standing.destination,
            velocity: standing.velocity.map { _ in 0 }, motion: standing.motion, completion: standing.completion,
            stopped: standing.stopped)
        XCTAssertTrue(
            HostBoundary.report(landed, updating: [.value, .velocity], through: binding), "the landing refused",
            file: file, line: line)
    }
}

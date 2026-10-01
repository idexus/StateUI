// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The act call a host is handed for a map, by the real typed call: the act's
// name, the view at 0, then each argument in its place, and whether a caller
// waits for the answer.

import XCTest
@_spi(Host) @testable import StateUI
import StateUIMap

final class MapActTests: XCTestCase {
    /// A map slides on three numbers after the view: latitude, longitude, and the radius in METERS.
    func testMovingAMapCrossesWithItsArgumentsInPlace() async throws {
        drainedActs()
        let task = await MainActor.run {
            Task.immediate { @MainActor in
                try await named("map", Map.self).moveToRegion(latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
            }
        }
        let batch = drainedActs()

        XCTAssertEqual(batch.map(\.act.name), ["moveToRegion"])
        XCTAssertEqual(batch.first?.arguments, [.string("map"), .number(52.2297), .number(21.0122), .number(3000)])
        XCTAssertNotNil(batch.first?.completion, "a caller waits for it")

        if let id = batch.compactMap(\.completion).first {
            HostBoundary.reply(id, with: [])
            await settle()
        }
        _ = try? await task.value
    }
}

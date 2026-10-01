// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance
import StateUIMap
@_spi(Host) import StateUIMapConformance

/// The map's conformance families: each covers its element and each member of its own, each case once by name.
final class MapFamilyTests: XCTestCase {
    func testTheMapFamilyCoversTheElementAndEachOfItsMembers() {
        XCTAssertEqual(Self.missing(MapTests.cases, of: MapContract.self), [], "MapTests has no case of these")
    }

    func testThePinFamilyCoversTheElementAndEachOfItsMembers() {
        XCTAssertEqual(Self.missing(PinTests.cases, of: PinContract.self), [], "PinTests has no case of these")
    }

    func testEveryCaseCoversSomethingUnderANameOfItsOwn() {
        for cases in [MapTests.cases, PinTests.cases] {
            let names = cases.map(\.name)
            XCTAssertEqual(Set(names).count, names.count)
            XCTAssertEqual(cases.filter { $0.proves.isEmpty }.map(\.name), [])
        }
    }

    /// The element itself, as "", and each member of its own no case of `cases` proves.
    static func missing(_ cases: [ConformanceCase], of contract: any ElementContract.Type) -> [String] {
        let element = contract.nodeType.name
        let covered = Set(cases.flatMap(\.proves).filter { $0.element == element && $0.tier == nil }
            .map { $0.member ?? "" })
        return ([""] + contract.members.map(\.name)).filter { !covered.contains($0) }
    }
}

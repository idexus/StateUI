// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import XCTest

/// The look of a bar's items, judged alike on every host: its records reach the bar's items and the bar alone,
/// whatever else wears the tiers their members belong to.
@MainActor
final class BarItemLookTests: XCTestCase {
    /// Every element a record of the look reaches - the element it names, or every element wearing its tier - is a
    /// bar's item or an arrangement holding a bar: a view wearing the same tier keeps its own judgment.
    func testItsRecordsReachTheBarsItemsAndTheBarAlone() {
        let bar = Set(["ToolbarButton", "ToolbarToggle", "ToolbarGroup"] + reached(by: BarElementContract.name))
        var wide: [String] = []

        for record in BarItemLook.realized + BarItemLook.notPlanned(reason: "The platform's own look.") {
            let beyond = Set(reached(by: record.owner)).subtracting(bar)
            if !beyond.isEmpty { wide.append("\(record.owner).\(record.member) reaches \(beyond.sorted())") }
        }

        XCTAssertEqual(wide, [])
    }

    /// The elements a record on `owner` reaches: the element it names, or every element wearing the tier.
    private func reached(by owner: String) -> [String] {
        LibraryContracts.elements.filter { element in element.worn.contains { $0.name == owner } }
            .map { $0.nodeType.name }
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// A contract's name is its own: a member's key is its contract's name and its own, so a second contract of one
/// name would write the first's keys.
final class ContractNamesTests: XCTestCase {
    private enum First {}
    private enum Second {}

    /// A name is taken by the first contract making a member under it; the same contract takes it again, and
    /// another is told which holds it.
    func testASecondContractOfOneNameIsRefused() {
        var names = ContractNames()

        XCTAssertNil(names.take(KeyName("Notes"), for: ObjectIdentifier(First.self), described: "First"))
        XCTAssertNil(names.take(KeyName("Notes"), for: ObjectIdentifier(First.self), described: "First"), "its own again")
        XCTAssertEqual(names.take(KeyName("Notes"), for: ObjectIdentifier(Second.self), described: "Second"), "First")
        XCTAssertNil(names.take(KeyName("Mail"), for: ObjectIdentifier(Second.self), described: "Second"), "another name")
    }

    /// The library's contracts are named each once, so none of its members crosses as another's.
    func testEveryLibraryContractHasANameOfItsOwn() {
        let names = LibraryContracts.all.map { $0.name }

        XCTAssertEqual(names.count, Set(names).count, "\(Dictionary(grouping: names) { $0 }.filter { $1.count > 1 }.keys)")
    }
}

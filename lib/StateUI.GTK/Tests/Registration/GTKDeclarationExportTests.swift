// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What this runtime says about itself, written to exports/ and held to it (`GTKExports`): the registrations are
// the declaration, so nothing here can disagree with the code.

import Foundation
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIGTK
import XCTest

final class GTKDeclarationExportTests: XCTestCase {
    /// The export is what the registry says, to the line.
    @MainActor
    func testWhatThisHostDeclaresIsWhatItExports() throws {
        try GTKExports.hold(GTKRealization.declaration.text, at: "gtk.txt")
    }

    /// The export is deterministic: the same registry writes the same text.
    @MainActor
    func testTheSameRegistryWritesTheSameText() {
        XCTAssertEqual(GTKRealization.declaration.text, GTKRealization.declaration.text)
    }

    /// Every name in the export is one the contracts declare.
    @MainActor
    func testEveryNameInTheExportIsOneTheContractsKnow() {
        let unknown = GTKRealization.declaration.undeclared

        XCTAssertTrue(
            unknown.isEmpty,
            "the GTK export names what no contract declares: "
                + unknown.map { "\($0.element).\($0.member)" }.joined(separator: ", "))
    }

    /// Every entry the host shows as unsupported is one its realization says it realizes none of, and none the
    /// registry makes is.
    @MainActor
    func testWhatThisHostShowsAsUnsupportedItSaysItRealizesNoneOf() {
        // A closure, not a key path: a key path through an existential metatype crashes Swift 6.4's SILGen.
        let types = LibraryContracts.elements.map { $0.nodeType }
        let unsupported = Set(types.filter { GTKElement.showsUnsupported($0) }.map(\.name))
        let made = Set(GTKRegistrations.registry.realization.elements)

        XCTAssertEqual(unsupported.subtracting(GTKRealization.unrealized).sorted(), [])
        XCTAssertEqual(made.intersection(GTKRealization.unrealized).sorted(), [])
    }

    /// What this host wrote of its register by hand is true of the contracts: no record names what its owner does
    /// not declare, none is written twice, a partial one says what is missing and a never says why.
    @MainActor
    func testTheRegisterThisHostWroteIsTrueOfTheContracts() {
        XCTAssertEqual(GTKRealization.register.problems, [])
    }
}

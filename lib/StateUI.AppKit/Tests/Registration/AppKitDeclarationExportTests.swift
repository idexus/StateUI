// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What this runtime says about itself, written to lib/exports/ and held to it.
//
// The registrations ARE the declaration: nothing here is written by hand, so
// nothing here can disagree with the code. What it says is PRESENCE - which
// member this host realizes on which element - never ownership, which the
// contracts answer when the documents are rendered.
//
// Run with STATEUI_UPDATE_EXPORTS=1 to write the export instead of checking
// it, then read it in the diff.

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

final class AppKitDeclarationExportTests: XCTestCase {
    /// The export is what the registry says, to the line.
    @MainActor
    func testWhatThisHostDeclaresIsWhatItExports() throws {
        try AppKitExports.hold(AppKitRealization.declaration.text, at: "appkit.txt")
    }

    /// The export is deterministic: the same registry writes the same text.
    @MainActor
    func testTheSameRegistryWritesTheSameText() {
        XCTAssertEqual(Self.declaration().text, Self.declaration().text)
    }

    /// Every name in the export is one the contracts declare - a host and the
    /// contracts disagreeing is a mistake on one side, never a row to render.
    @MainActor
    func testEveryNameInTheExportIsOneTheContractsKnow() {
        let unknown = Self.declaration().undeclared

        XCTAssertTrue(
            unknown.isEmpty,
            "the AppKit export names what no contract declares: "
                + unknown.map { "\($0.element).\($0.member)" }.joined(separator: ", "))
    }

    /// The declaration carries the three kinds apart: what a control takes,
    /// what it raises, and what the host performs.
    @MainActor
    func testTheDeclarationCarriesMembersEventsAndActs() throws {
        let declaration = Self.declaration()
        let slider = try XCTUnwrap(declaration.elements["Slider"])

        XCTAssertTrue(slider.members.isSuperset(of: ["value", "minimum", "maximum"]))
        XCTAssertTrue(slider.events.contains("valueChanged"))
        XCTAssertTrue(declaration.shared.members.contains("margin"))
        XCTAssertTrue(declaration.shared.events.contains("tapped"))
        XCTAssertTrue(declaration.acts.isSuperset(of: ["focus", "unfocus", "persistValue"]))
    }

    /// What this host wrote of its register by hand is true of the contracts: no record names what its owner does
    /// not declare, none is written twice, a partial one says what is missing and a never says why.
    @MainActor
    func testTheRegisterThisHostWroteIsTrueOfTheContracts() {
        XCTAssertEqual(AppKitRealization.register.problems, [])
    }

    @MainActor
    private static func declaration() -> HostDeclaration {
        AppKitRealization.declaration
    }
}

#endif

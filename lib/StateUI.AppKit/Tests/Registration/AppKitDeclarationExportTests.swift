// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What this runtime says about itself, written to exports/ and held to it.
//
// The registrations ARE the declaration: nothing here is written by hand, so
// nothing here can disagree with the code. What it says is PRESENCE - which
// member this host realizes on which element - never ownership, which the
// contracts answer when the documents are rendered.
//
// Run with STATEUI_UPDATE_EXPORTS=1 to write the export instead of checking
// it, then read the .txt sidecar in the diff.

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitDeclarationExportTests: XCTestCase {
    /// The export is what the registry says, to the byte and to the line.
    @MainActor
    func testWhatThisHostDeclaresIsWhatItExports() throws {
        let declaration = Self.declaration()
        let bytes = Wire.encodeDeclaration(declaration)
        let sidecar = declaration.sidecar
        let binary = Self.exports.appendingPathComponent("appkit.bin")
        let text = Self.exports.appendingPathComponent("appkit.txt")

        if ProcessInfo.processInfo.environment["STATEUI_UPDATE_EXPORTS"] == "1" {
            try FileManager.default.createDirectory(
                at: Self.exports, withIntermediateDirectories: true)
            try Data(bytes).write(to: binary)
            try sidecar.write(to: text, atomically: true, encoding: .utf8)
            return
        }

        let hint = """


            Either a registration changed - in which case run the suite again \
            with STATEUI_UPDATE_EXPORTS=1 and read the diff - or something \
            stopped being realized.
            """

        XCTAssertEqual(Data(bytes), try Data(contentsOf: binary), "exports/appkit.bin\(hint)")
        XCTAssertEqual(
            sidecar, try String(contentsOf: text, encoding: .utf8), "exports/appkit.txt\(hint)")
    }

    /// The export is deterministic: the same registry writes the same bytes.
    @MainActor
    func testTheSameRegistryWritesTheSameBytes() {
        XCTAssertEqual(
            Wire.encodeDeclaration(Self.declaration()),
            Wire.encodeDeclaration(Self.declaration()))
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

    // MARK: - Support

    /// `exports`, a directory of its own: every fixture is authored by the
    /// core's tests, while an export is written by a RUNTIME saying what it
    /// realizes.
    private static var exports: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Registration
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // StateUI.AppKit
            .deletingLastPathComponent()    // lib
            .deletingLastPathComponent()    // the repository
            .appendingPathComponent("exports")
    }

    /// What this host declares, read off its registry.
    @MainActor
    private static func declaration() -> HostDeclaration {
        let registry = AppKitRegistrations.registry
        return HostDeclaration(
            realization: registry.realization, shared: registry.sharedNames,
            acts: AppKitRegistrations.acts.map(\.name))
    }
}

#endif

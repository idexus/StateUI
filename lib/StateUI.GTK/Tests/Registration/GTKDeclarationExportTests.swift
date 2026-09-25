// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What this runtime says about itself, written to exports/ and held to it: the registrations are the declaration,
// so nothing here can disagree with the code. Run with STATEUI_UPDATE_EXPORTS=1 to write the export instead of
// checking it, then read it in the diff.

import Foundation
@_spi(Host) @testable import StateUI
@testable import StateUIGTK
import XCTest

final class GTKDeclarationExportTests: XCTestCase {
    /// The export is what the registry says, to the line.
    @MainActor
    func testWhatThisHostDeclaresIsWhatItExports() throws {
        let exported = GTKRealization.declaration.text
        let file = Self.exports.appendingPathComponent("gtk.txt")

        if ProcessInfo.processInfo.environment["STATEUI_UPDATE_EXPORTS"] == "1" {
            try FileManager.default.createDirectory(at: Self.exports, withIntermediateDirectories: true)
            try exported.write(to: file, atomically: true, encoding: .utf8)
            return
        }

        XCTAssertEqual(
            exported, try String(contentsOf: file, encoding: .utf8),
            "exports/gtk.txt: either a registration changed - run the suite again with STATEUI_UPDATE_EXPORTS=1 "
                + "and read the diff - or something stopped being realized.")
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

    // MARK: - Support

    /// `exports`, beside `lib`: an export is written by a runtime saying what it realizes.
    private static var exports: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Registration
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // StateUI.GTK
            .deletingLastPathComponent()    // lib
            .deletingLastPathComponent()    // the repository
            .appendingPathComponent("exports")
    }
}

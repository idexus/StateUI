// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// The C boundary the library exports: one file of `@_cdecl`s, each name
/// once. Read out of the sources - a regex over source code is acceptable in a
/// TEST, where it can only under-report, and never in anything the library
/// runs.
final class BridgeTests: XCTestCase {
    /// `Exports.swift`, the one place `@_cdecl` is allowed.
    private func exports() throws -> String {
        try String(
            contentsOf: Fixtures.sources
                .appendingPathComponent("Bridge")
                .appendingPathComponent("Exports.swift"),
            encoding: .utf8)
    }

    /// Every exported entry point has one unambiguous name.
    func testEveryExportNameIsUnique() throws {
        let names = try exports().occurrences(between: "@_cdecl(\"", and: "\")")

        XCTAssertFalse(names.isEmpty, "no exports found - the scan is broken")
        XCTAssertEqual(Set(names).count, names.count, "two exports carry the same C name")
    }

    /// Every `@_cdecl` in the library is in `Exports.swift`.
    func testEveryExportLivesInTheBridgeFile() throws {
        for (path, text) in try Fixtures.allSources()
        where !path.hasSuffix("/Exports.swift") {
            let code = text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.drop(while: { $0 == " " }) }
                .filter { !$0.hasPrefix("//") }
                .joined(separator: "\n")

            XCTAssertFalse(
                code.contains("@_cdecl(\""),
                "\(path) declares an export; they all belong in Exports.swift")
        }
    }

    /// The environment a host pushes before the first render is readable while
    /// the tree is built.
    func testTheEnvironmentTheHostPushesIsReadableAtBuildTime() {
        defer {
            StandardEnvironment.device.formFactor = .unknown
            Renderer.shared.clearInvalidation()
        }

        XCTAssertEqual(StandardEnvironment.device.formFactor, .unknown)

        var out: [UInt8] = []
        out.u8(Wire.version)
        out.u8(5)
        out.u8(7)
        for value in [
            PropValue.enumeration(FormFactor.desktop.rawValue), .string("macOS"),
            .string(""), .string(""), .string(""), .string(""),
            .enumeration(DeviceType.physical.rawValue),
        ] {
            out.value(value)
        }

        let applied = out.withUnsafeBufferPointer {
            stateui_set_environment($0.baseAddress, Int32($0.count))
        }

        XCTAssertEqual(applied, 1)
        XCTAssertEqual(StandardEnvironment.device.formFactor, .desktop)
    }
}

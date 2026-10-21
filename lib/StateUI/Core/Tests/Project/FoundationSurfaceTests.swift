// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// `StateUIFoundation` is the platform's C library behind one import: an
/// application that imports it meets that library and nothing of the
/// foundation's own. What the foundation builds on the library - which thread
/// runs, the environment, the standard error - is the host's, behind
/// `@_spi(Host)`.
///
/// Design: docs/design/foundation/c-library.md
final class FoundationSurfaceTests: XCTestCase {
    /// Every foundation source, as `(path, text)`.
    private static func sources() throws -> [(path: String, text: String)] {
        try SourceTree.allSources().filter { $0.path.hasPrefix("StateUIFoundation/") }
    }

    /// NOTHING PUBLIC OF ITS OWN: every declaration the foundation opens is
    /// the host's.
    func testItDeclaresNothingPublicOfItsOwn() throws {
        let sources = try Self.sources()
        XCTAssertFalse(sources.isEmpty, "no foundation source was read")

        for (path, text) in sources {
            for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//"), code.range(of: #"\b(public|open)\s"#, options: .regularExpression) != nil
                else { continue }

                XCTAssertTrue(code.contains("@_spi(Host)"), "\(path):\(number + 1) opens `\(code)` to an "
                    + "application - the foundation passes its C library on and keeps its own for the host")
            }
        }
    }

    /// A CONDITION ASKS FOR A MODULE ONLY TO IMPORT IT: `canImport` stands
    /// before an import, and what a platform does is asked by `os()`.
    func testItAsksForAModuleOnlyToImportIt() throws {
        for (path, text) in try Self.sources() {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            for (number, line) in lines.enumerated() where line.contains("canImport(") {
                let next = lines.dropFirst(number + 1).first { !$0.isEmpty } ?? ""

                XCTAssertTrue(next.hasPrefix("import ") || next.hasPrefix("@_exported import "),
                    "\(path):\(number + 1) asks `\(line)` and then does `\(next)` - what a platform does is "
                        + "asked by os()")
            }
        }
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

final class LicenceTests: XCTestCase {
    /// Every Swift, C# and TypeScript source under `lib/` starts with the two
    /// SPDX lines.
    ///
    /// Outside the rule: `Package.swift`, whose first line must be the tools
    /// version, the template an application is generated from, and what a
    /// build writes - `node_modules` and `out` among it, which the editor
    /// extension's tools install and compile into.
    func testEverySourceUnderLibCarriesTheLicenceHeader() throws {
        let lib = Fixtures.repository.appendingPathComponent("lib")
        let generated: Set<String> = ["bin", "obj", "templates", "node_modules", "out"]
        let entered = { (path: String) -> Bool in
            let name = String(path.split(separator: "/").last ?? "")
            return !name.hasPrefix(".") && !generated.contains(name)
        }

        var read = 0
        var missing: [String] = []
        for path in try Fixtures.files(under: lib, entering: entered) {
            let name = String(path.split(separator: "/").last ?? "")
            guard !name.hasPrefix("."),
                  ["swift", "cs", "ts"].contains(URL(fileURLWithPath: name).pathExtension),
                  name != "Package.swift" else { continue }

            read += 1
            let lines = try String(contentsOf: lib.appendingPathComponent(path), encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)

            if lines.count < 2
                || lines[0] != "// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors"
                || lines[1] != "// SPDX-License-Identifier: Apache-2.0" {
                missing.append("lib/\(path)")
            }
        }

        XCTAssertGreaterThan(read, 300, "the walk read almost nothing")
        XCTAssertEqual(missing.sorted(), [])
    }
}

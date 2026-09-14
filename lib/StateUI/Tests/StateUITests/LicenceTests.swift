// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

final class LicenceTests: XCTestCase {
    /// Every Swift and C# source under `lib/` starts with the two SPDX lines.
    ///
    /// Outside the rule: `Package.swift`, whose first line must be the tools
    /// version, the template an application is generated from, and what a
    /// build writes.
    func testEverySourceUnderLibCarriesTheLicenceHeader() throws {
        let lib = Fixtures.repository.appendingPathComponent("lib")
        let generated: Set<String> = ["bin", "obj", ".build", "templates"]

        guard let walk = FileManager.default.enumerator(
            at: lib,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return XCTFail("lib could not be enumerated")
        }

        var read = 0
        var missing: [String] = []
        for case let file as URL in walk {
            if generated.contains(file.lastPathComponent) {
                walk.skipDescendants()
                continue
            }

            guard ["swift", "cs"].contains(file.pathExtension),
                  file.lastPathComponent != "Package.swift" else { continue }

            read += 1
            let relative = file.path.replacingOccurrences(of: Fixtures.repository.path + "/", with: "")
            let lines = try String(contentsOf: file, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)

            if lines.count < 2
                || lines[0] != "// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors"
                || lines[1] != "// SPDX-License-Identifier: Apache-2.0" {
                missing.append(relative)
            }
        }

        XCTAssertGreaterThan(read, 300, "the walk read almost nothing")
        XCTAssertEqual(missing.sorted(), [])
    }
}

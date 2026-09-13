// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

final class LicenceTests: XCTestCase {
    func testEveryActiveSourceUnderSrcCarriesTheLicenceHeader() throws {
        let src = Fixtures.repository.appendingPathComponent("src")
        let manager = FileManager.default
        guard let walk = manager.enumerator(
            at: src,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return XCTFail("src could not be enumerated")
        }

        var missing: [String] = []
        for case let file as URL in walk {
            guard file.pathExtension == "swift", file.lastPathComponent != "Package.swift" else {
                continue
            }
            let relative = file.path.replacingOccurrences(of: Fixtures.repository.path + "/", with: "")
            let source = try String(contentsOf: file, encoding: .utf8)
            let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
            if lines.count < 2
                || lines[0] != "// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors"
                || lines[1] != "// SPDX-License-Identifier: Apache-2.0" {
                missing.append(relative)
            }
        }

        XCTAssertEqual(missing.sorted(), [])
    }
}


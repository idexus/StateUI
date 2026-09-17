// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
import XCTest

final class AppKitProgramWriteTests: XCTestCase {
    /// One mark says a native control is being written by the program: no
    /// control keeps a flag of its own, so an application write cannot echo
    /// back as a reader's report through a control that forgot to raise one.
    func testNoControlKeepsAWriteFlagOfItsOwn() throws {
        let flag = try NSRegularExpression(pattern: #"\bvar\s+(applying\w*)\b"#)
        var found: [String] = []

        for (name, text) in try AppKitSources.all() {
            for match in flag.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                found.append("\(name): \(text[range])")
            }
        }

        XCTAssertEqual(found, [], "a program's write is marked by AppKitProgramWrite alone")
    }
}
#endif

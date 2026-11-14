// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class WinUIPackagesTests: XCTestCase {
    /// While `tools.ps1` records the WinUI host's marks, it pins what the tool pins: one version of each package.
    func testTheRecordingScriptPinsWhatTheToolPins() throws {
        let script = ProjectReaderTests.repository.appendingPathComponent(".scripts/WinUI/tools.ps1")
        guard let text = try? String(contentsOf: script, encoding: .utf8) else { return }
        let pinned = text.split(whereSeparator: \.isNewline).compactMap { line -> (String, String)? in
            let words = line.split(separator: "'").map(String.init)
            return words.count == 4 && words[2].trimmingCharacters(in: .whitespaces) == "=" ? (words[1], words[3]) : nil
        }
        XCTAssertEqual(pinned.map { "\($0.0) \($0.1)" }.joined(separator: "\n"), WinUIPackages.stamp)
    }

    /// The projection's stamp lists every pin, a line each, in the order the script writes it.
    func testTheStampListsEveryPin() {
        XCTAssertEqual(WinUIPackages.stamp.split(separator: "\n").count, WinUIPackages.pins.count)
        XCTAssertTrue(WinUIPackages.stamp.hasPrefix("microsoft.windows.cppwinrt 3.0."))
        XCTAssertThrowsError(try WinUIPackages.version(of: "microsoft.other"))
    }

    #if os(Windows)
    /// Windows' own SHA-512 gives the digest of the standard's example.
    func testTheSystemsSHA512() throws {
        XCTAssertEqual(try WindowsHash.sha512(Data("abc".utf8)).base64EncodedString(),
                       "3a81oZNherrMQXNJriBBMRLm+k6JqX6iCp7u5ktV05ohkpkqJ0/BqDa6PCOj/uu9RU1EI2Q86A4qmslPpUyknw==")
    }
    #endif
}

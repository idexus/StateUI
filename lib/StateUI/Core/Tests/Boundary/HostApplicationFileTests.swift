// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// A head whose platform keeps no record of the application carries its `stateui.json`, which its host reads as what
/// the application is.
@MainActor
final class HostApplicationFileTests: XCTestCase {
    /// The file the tool lays reads as the application's name shown, identifier, version and build.
    func testAnApplicationsFileReadsAsWhatItIs() throws {
        let file = #"{"build" : 7, "identifier" : "pl.example.notes", "name" : "My Notes", "schemaVersion" : 1, "version" : "1.2"}"#
        let info = try XCTUnwrap(HostApplicationInfo(applicationFile: Array(file.utf8)))
        XCTAssertEqual(info, HostApplicationInfo(name: "My Notes", packageName: "pl.example.notes", version: "1.2", build: "7"))
    }

    /// Bytes that are no such file - no JSON, no object, a field missing or of another kind - read as nothing.
    func testWhatIsNoApplicationsFileReadsAsNothing() {
        for text in [
            "", "not json", "[1]", #"{"identifier":"a.b","name":"N","version":"1"}"#,
            #"{"build":"7","identifier":"a.b","name":"N","version":"1"}"#,
        ] {
            XCTAssertNil(HostApplicationInfo(applicationFile: Array(text.utf8)), text)
        }
    }
}

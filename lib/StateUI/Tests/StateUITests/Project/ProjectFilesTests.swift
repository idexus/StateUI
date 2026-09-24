// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import XCTest

final class ProjectFilesTests: XCTestCase {
    /// Every project, targets and solution file of the build reads as XML.
    ///
    /// MSBuild refuses the whole build over one malformed line, and the most
    /// likely one is a comment: `--` is not allowed inside `<!-- -->`, so a
    /// command-line option written into an explanation - `--stateui-path` -
    /// breaks every head that imports the file. The suites build no head, so a
    /// file only a head reads is read here instead.
    func testEveryProjectAndTargetsFileIsWellFormedXML() throws {
        let repository = Fixtures.repository
        let kinds: Set<String> = ["csproj", "targets", "props", "slnx"]

        // What a build or a pack writes is not the build's own file: bin/, obj/,
        // .build/ and each host's .build-appkit/, .build-maui/ and .build-android/, and the
        // editor extension's node_modules/.
        let written: Set<String> = [
            ".build", ".build-appkit", ".build-maui", ".build-android", ".git", ".gradle", "bin", "node_modules", "obj",
        ]

        let entered = { (relative: String) -> Bool in
            let name = String(relative.split(separator: "/").last ?? "")
            return !written.contains(name)
        }

        var read = 0
        var malformed: [String] = []

        for relative in try Fixtures.files(under: repository, entering: entered) {
            guard kinds.contains(URL(fileURLWithPath: relative).pathExtension) else { continue }

            read += 1
            let parser = XMLParser(data: try Data(contentsOf: repository.appendingPathComponent(relative)))

            if !parser.parse() {
                malformed.append("\(relative):\(parser.lineNumber)")
            }
        }

        XCTAssertGreaterThan(read, 6, "the walk found almost none of the build's files")
        XCTAssertEqual(malformed, [], "MSBuild cannot read these as XML")
    }
}

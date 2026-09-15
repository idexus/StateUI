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

        // What a build or a pack writes is not the build's own file: bin/, obj/
        // and .build/, and the template's copy of .scripts/, which its project
        // makes as it builds.
        let written: Set<String> = [".build", ".git", "bin", "obj"]

        guard let walk = FileManager.default.enumerator(
            at: repository, includingPropertiesForKeys: nil)
        else {
            return XCTFail("the repository at \(repository.path) could not be walked")
        }

        var read = 0
        var malformed: [String] = []

        // Forward slashes on every host: a walk on Windows yields backslashes.
        let root = repository.path.replacingOccurrences(of: "\\", with: "/")

        for case let file as URL in walk {
            let path = file.path.replacingOccurrences(of: "\\", with: "/")
            let relative = String(path.dropFirst(root.count + 1))

            if written.contains(file.lastPathComponent)
                || (file.lastPathComponent == ".scripts" && relative.contains("/Template/templates/"))
            {
                walk.skipDescendants()
                continue
            }

            guard kinds.contains(file.pathExtension) else { continue }

            read += 1
            let parser = XMLParser(data: try Data(contentsOf: file))

            if !parser.parse() {
                malformed.append("\(relative):\(parser.lineNumber)")
            }
        }

        XCTAssertGreaterThan(read, 8, "the walk found almost none of the build's files")
        XCTAssertEqual(malformed, [], "MSBuild cannot read these as XML")
    }
}

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Every source file says who wrote it and under what terms.
//
// LICENSE in the repository root is what licenses the work, and it would go on
// doing that if not one file carried a word. What a header adds is PROVENANCE
// for a file that travels ALONE: a package manager hands a consumer the whole
// checkout - the tests with it - and a file lifted out of that into somebody
// else's project keeps nothing else about where it came from.
//
// Two SPDX lines rather than the thirteen of the licence's own appendix.
// `SPDX-License-Identifier` is what licence scanners read, so the short form
// says the same thing to the tools that ask, and it fits above `import`
// without pushing the first meaningful line of every file down the screen.
//
// ONE test for both languages. The rule is one sentence and its exclusions are
// one list; checking each half where it compiles would be two lists to keep in
// step, and the C# compiler cannot be made to ask for a comment anyway.

import Foundation
import XCTest
@testable import StateUI

final class LicenceTests: XCTestCase {
    /// The two lines every source under `src/` starts with, in order.
    private static let header = [
        "// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors",
        "// SPDX-License-Identifier: Apache-2.0",
    ]

    /// Names every source that does not carry the notice.
    ///
    /// The check is on the FIRST two lines, not on the file containing them
    /// somewhere: a notice below a file's own preamble is one a reader has to
    /// go looking for, and a copy taken from the top of the file would miss it.
    func testEverySourceCarriesTheLicenceHeader() throws {
        var bare: [String] = []

        for source in try Fixtures.licensedSources() {
            let lines = source.text.components(separatedBy: "\n")

            if Array(lines.prefix(2)) != Self.header {
                bare.append(source.path)
            }
        }

        XCTAssertEqual(bare, [], """
            These sources under src/ do not start with the licence notice:

            \(bare.joined(separator: "\n"))

            Put these two lines at the top of each, with a blank line under them:

            \(Self.header.joined(separator: "\n"))

            A file that leaves this repository on its own - copied out of a
            checkout, pasted into somebody's project - carries nothing else
            saying whose it is.
            """)
    }

    /// The holder and the licence are named in five places, and a change of
    /// either would be five edits.
    ///
    /// The sources say it through this header, NOTICE says it in prose, the two
    /// packages say it as metadata a gallery displays, and CONTRIBUTING.md
    /// quotes the header at the contributor who has to write it. Nothing makes
    /// them agree except this, and the last is the one that fails quietly: a
    /// document telling somebody to paste two lines that are no longer the two
    /// lines reads exactly like a correct document.
    func testTheHeaderIsSpelledTheSameEverywhereItIsNamed() throws {
        let holder = "2026 Paweł Krzywdziński and Contributors"
        let licence = "Apache-2.0"

        let notice = try String(
            contentsOf: Fixtures.repository.appendingPathComponent("NOTICE"), encoding: .utf8)

        XCTAssertTrue(notice.contains(holder), """
            NOTICE does not name "\(holder)", which is what every source header
            says. One of the two has been changed and the other has not.
            """)

        for project in ["src/StateUI.Runtime/StateUI.Runtime.csproj",
                        "src/StateUI.Template/StateUI.Template.csproj"] {
            let text = try String(
                contentsOf: Fixtures.repository.appendingPathComponent(project), encoding: .utf8)

            XCTAssertTrue(text.contains("<Copyright>Copyright \(holder)</Copyright>"), """
                \(project) does not carry <Copyright>Copyright \(holder)</Copyright>,
                which is what every source header and NOTICE say.
                """)

            XCTAssertTrue(
                text.contains("<PackageLicenseExpression>\(licence)</PackageLicenseExpression>"),
                """
                \(project) does not declare \(licence), which is the identifier
                every source header carries.
                """)
        }

        // CONTRIBUTING.md QUOTES the header, so a contributor can paste it. A
        // quotation is a copy, and this is what keeps it one.
        let contributing = try String(
            contentsOf: Fixtures.repository.appendingPathComponent("CONTRIBUTING.md"),
            encoding: .utf8)

        for line in Self.header {
            XCTAssertTrue(contributing.contains(line), """
                CONTRIBUTING.md does not show "\(line)", which is a line every
                source under src/ starts with. It tells a contributor what to
                paste at the top of a new file, so a stale copy there is a
                document that reads correctly and is wrong.
                """)
        }
    }
}

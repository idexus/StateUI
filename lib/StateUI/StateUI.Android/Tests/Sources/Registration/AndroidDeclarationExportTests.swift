// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAndroid
import XCTest

/// What this host declares, written where `test-android.sh` reads it from and holds `lib/StateUI/exports/` to it.
final class AndroidDeclarationExportTests: XCTestCase {
    static var allTests: [(String, (AndroidDeclarationExportTests) -> () throws -> Void)] {
        [
            ("testWhatThisHostDeclaresIsWrittenForTheExport", testWhatThisHostDeclaresIsWrittenForTheExport),
            ("testTheRegisterThisHostWroteIsTrueOfTheContracts", testTheRegisterThisHostWroteIsTrueOfTheContracts),
        ]
    }

    /// The registry's declaration, every name one the contracts know, written as text.
    func testWhatThisHostDeclaresIsWrittenForTheExport() throws {
        try onMainActor {
            let declaration = AndroidRealization.declaration

            XCTAssertTrue(
                declaration.undeclared.isEmpty,
                "the Android export names what no contract declares: "
                    + declaration.undeclared.map { "\($0.element).\($0.member)" }.joined(separator: ", "))
            XCTAssertEqual(declaration.text, declaration.text)

            try TestFiles.write(declaration.text, to: "android.txt")
        }
    }

    /// What this host wrote of its register by hand is true of the contracts: no record names what its owner does
    /// not declare, none is written twice, a partial one says what is missing and a never says why.
    func testTheRegisterThisHostWroteIsTrueOfTheContracts() {
        onMainActor {
            XCTAssertEqual(AndroidRealization.register.problems, [])
        }
    }
}

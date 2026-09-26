// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAndroid
import XCTest

/// What this host declares, written where `test-android.sh` reads it from and holds `exports/` to it.
final class AndroidDeclarationExportTests: XCTestCase {
    static var allTests: [(String, (AndroidDeclarationExportTests) -> () throws -> Void)] {
        [
            ("testWhatThisHostDeclaresIsWrittenForTheExport", testWhatThisHostDeclaresIsWrittenForTheExport),
        ]
    }

    /// The registry's declaration, every name one the contracts know, written as text.
    func testWhatThisHostDeclaresIsWrittenForTheExport() throws {
        try onMainActor {
            let registry = AndroidRegistrations.registry
            let declaration = HostDeclaration(
                realization: registry.realization, shared: registry.sharedNames,
                acts: AndroidRegistrations.acts.map(\.name))

            XCTAssertTrue(
                declaration.undeclared.isEmpty,
                "the Android export names what no contract declares: "
                    + declaration.undeclared.map { "\($0.element).\($0.member)" }.joined(separator: ", "))
            XCTAssertEqual(declaration.text, declaration.text)

            let directory = try XCTUnwrap(Self.filesDirectory)
            try Self.write(Array(declaration.text.utf8), to: "\(directory)/android.txt")
        }
    }

    /// The test APK's own files directory, which `run-as` reads.
    @MainActor
    private static var filesDirectory: String? {
        Java.frame {
            guard let files = Java.callObject(TestContext.context.reference, TestJava.getFilesDir) else { return nil }
            return Java.text(Java.callObject(files, TestJava.getAbsolutePath))
        }
    }

    /// Writes `bytes` to `path` whole.
    private static func write(_ bytes: [UInt8], to path: String) throws {
        guard let file = fopen(path, "wb") else { throw Unwritable(path: path) }
        defer { fclose(file) }
        guard fwrite(bytes, 1, bytes.count, file) == bytes.count else { throw Unwritable(path: path) }
    }

    private struct Unwritable: Error {
        let path: String
    }
}

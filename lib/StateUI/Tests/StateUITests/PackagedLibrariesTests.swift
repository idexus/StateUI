// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// What the Android and Linux heads ship is copied by `.scripts/Maui/libraries.sh`,
/// and a copy left in place from another toolchain is a runtime the
/// application's libraries were not built against - a device that refuses to
/// load them, with every build step reading as a success.
final class PackagedLibrariesTests: XCTestCase {
    /// Runs `body` in bash with libraries.sh sourced and a fresh directory as
    /// `$work`, and answers what it printed.
    private func bash(_ body: String) throws -> String {
        let bash = URL(fileURLWithPath: "/bin/bash")

        guard FileManager.default.fileExists(atPath: bash.path) else {
            throw XCTSkip("no /bin/bash here; the Windows head copies its runtime with Copy-Item -Force.")
        }

        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-libraries-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        let script = Fixtures.repository.appendingPathComponent(".scripts/Maui/libraries.sh")

        let process = Process()
        process.executableURL = bash
        process.arguments = ["-c", "set -euo pipefail\nsource \"$0\"\nwork=\"$1\"\n" + body, script.path, work.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let said = String(decoding: output, as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 0, said)
        return said
    }

    /// A toolchain whose files are OLDER than the copies an earlier build left
    /// - an SDK installed a week ago, a build from yesterday - still replaces
    /// them. What decides is that the two differ, not which one is newer.
    func testAnotherToolchainsRuntimeReplacesTheCopyWhateverItsAge() throws {
        let said = try bash("""
            mkdir -p "$work/sdk" "$work/app"
            printf 'the runtime the application was built against' > "$work/sdk/libswiftCore.so"
            touch -t 202609140035 "$work/sdk/libswiftCore.so"
            printf 'another release' > "$work/app/libswiftCore.so"
            printf 'nothing ships this' > "$work/app/libgone.so"

            install_so "$work/sdk/libswiftCore.so" "$work/app"
            remove_the_rest "$work/app"

            cat "$work/app/libswiftCore.so"; echo
            ls "$work/app"
            """)

        XCTAssertEqual(
            said, "the runtime the application was built against\nlibswiftCore.so\n",
            "the copy an earlier toolchain left must give way, and what nothing ships must go")
    }

    /// A library that has not moved is left where it is: the copy carries its
    /// source's time, and the same time is the same file.
    func testAnUnchangedLibraryIsNotCopiedAgain() throws {
        let said = try bash("""
            mkdir -p "$work/sdk" "$work/app"
            printf 'runtime' > "$work/sdk/libswiftCore.so"
            install_so "$work/sdk/libswiftCore.so" "$work/app"

            printf 'left alone' > "$work/app/libswiftCore.so"
            touch -r "$work/sdk/libswiftCore.so" "$work/app/libswiftCore.so"
            install_so "$work/sdk/libswiftCore.so" "$work/app"

            cat "$work/app/libswiftCore.so"
            """)

        XCTAssertEqual(said, "left alone", "a library that did not move was copied again")
    }
}

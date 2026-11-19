// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@_spi(Host) import StateUI
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import WinSDK
import XCTest

/// A WinUI head carries the application's `stateui.json` beside its program; the host reads it there.
final class WinUIApplicationFileTests: XCTestCase {
    /// The file beside the program reads as what the application is; with none beside it, the program's name alone.
    func testTheFileBesideTheProgramIsWhatTheApplicationIs() throws {
        var path = [WCHAR](repeating: 0, count: Int(MAX_PATH))
        let length = Int(GetModuleFileNameW(nil, &path, DWORD(MAX_PATH)))
        let program = URL(fileURLWithPath: String(decoding: path[..<length], as: UTF16.self))
        let file = program.deletingLastPathComponent().appendingPathComponent("stateui.json")
        try? FileManager.default.removeItem(at: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let name = program.deletingPathExtension().lastPathComponent
        onUIThread {
            XCTAssertEqual(
                WinUIEnvironment.application(), HostApplicationInfo(name: name, packageName: "", version: "", build: ""))
        }

        try #"{"build":3,"identifier":"pl.example.notes","name":"My Notes","schemaVersion":1,"version":"2.1"}"#
            .write(to: file, atomically: true, encoding: .utf8)
        onUIThread {
            XCTAssertEqual(
                WinUIEnvironment.application(),
                HostApplicationInfo(name: "My Notes", packageName: "pl.example.notes", version: "2.1", build: "3"))
        }
    }
}

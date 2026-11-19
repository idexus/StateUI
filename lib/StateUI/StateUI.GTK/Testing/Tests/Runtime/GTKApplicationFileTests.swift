// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIGTK
import Foundation
import XCTest

/// A GTK head carries the application's `stateui.json` beside its program; the host reads it there.
final class GTKApplicationFileTests: XCTestCase {
    /// The file beside a program reads as what the application is; a program with none beside it reads as none.
    func testTheFileBesideTheProgramIsWhatTheApplicationIs() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("gtk-head-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let program = folder.appendingPathComponent("NotesGTK").path
        XCTAssertNil(GTKHost.carried(beside: program))

        try #"{"build":3,"identifier":"pl.example.notes","name":"My Notes","schemaVersion":1,"version":"2.1"}"#
            .write(to: folder.appendingPathComponent("stateui.json"), atomically: true, encoding: .utf8)
        XCTAssertEqual(
            GTKHost.carried(beside: program),
            HostApplicationInfo(name: "My Notes", packageName: "pl.example.notes", version: "2.1", build: "3"))
    }
}

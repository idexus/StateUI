// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

/// A path the tool hands on is the path it has: dots taken out, nothing else rewritten.
final class FileURITests: XCTestCase {
    /// A real path keeps every component through its URI and back - `/private` on macOS included, which Foundation's
    /// `standardizedFileURL` leaves off.
    func testARealPathKeepsItsComponentsThroughItsURI() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("uri-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let real = RealPath.of(folder)

        let uri = FileURI.string(real)

        XCTAssertEqual(try FileURI.url(uri).path, real.path)
        XCTAssertEqual(URL(string: uri)?.path, real.path)
        XCTAssertEqual(FileURI.string(real.appendingPathComponent("a/./b/../c")), FileURI.string(real.appendingPathComponent("a/c")))
    }

    /// Dots go lexically: `.` is left out and `..` takes the folder before it, links left as they are.
    func testDotsAreTakenOutLexically() {
        #if !os(Windows)
        XCTAssertEqual(RealPath.lexical(URL(fileURLWithPath: "/private/tmp/a/./b/../c")).path, "/private/tmp/a/c")
        XCTAssertEqual(RealPath.lexical(URL(fileURLWithPath: "/a/../../b")).path, "/b")
        XCTAssertEqual(RealPath.lexical(URL(fileURLWithPath: "/")).path, "/")
        #endif
    }

    /// A file of a Windows drive is shown as Windows writes it, wherever it is told - a guest's on a Mac; any other as its
    /// path.
    func testAFileIsShownAsItsMachineWritesIt() {
        XCTAssertEqual(FileURI.shown("file:///C:/Users/me/stateui-guest/a%20b.exe"), #"C:\Users\me\stateui-guest\a b.exe"#)
        #if !os(Windows)
        XCTAssertEqual(FileURI.shown("file:///home/me/stateui-guest/Notes%20GTK"), "/home/me/stateui-guest/Notes GTK")
        #endif
    }
}

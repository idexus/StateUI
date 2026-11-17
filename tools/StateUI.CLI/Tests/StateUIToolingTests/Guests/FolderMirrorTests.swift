// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class FolderMirrorTests: XCTestCase {
    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mirror-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    private func write(_ text: String, _ relative: String, in folder: URL) throws {
        let file = folder.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }

    private func text(_ relative: String, in folder: URL) -> String? {
        try? String(contentsOf: folder.appendingPathComponent(relative), encoding: .utf8)
    }

    /// A mirror copies every file, then only what changed; it removes what the source lost, and leaves what a build
    /// makes - `.build` - on both sides as it stands.
    func testAMirrorCopiesWhatChangedAndRemovesWhatWent() throws {
        let (source, target) = (try folder(), try folder())
        try write("one", "Sources/A.swift", in: source)
        try write("two", "Package.swift", in: source)
        try write("built", ".build/x.o", in: source)
        try write("mine", ".build/y.o", in: target)
        let request = FolderMirrorRequest(sourcePath: source.path, targetPath: target.path)

        XCTAssertEqual(try FolderMirror().mirror(request), FolderMirrorResult(copied: 2, removed: 0, unchanged: 0))
        XCTAssertEqual(text("Sources/A.swift", in: target), "one")
        XCTAssertNil(text(".build/x.o", in: target))
        XCTAssertEqual(try FolderMirror().mirror(request), FolderMirrorResult(copied: 0, removed: 0, unchanged: 2))

        try write("one more", "Sources/A.swift", in: source)
        try FileManager.default.removeItem(at: source.appendingPathComponent("Package.swift"))
        XCTAssertEqual(try FolderMirror().mirror(request), FolderMirrorResult(copied: 1, removed: 1, unchanged: 0))
        XCTAssertEqual(text("Sources/A.swift", in: target), "one more")
        XCTAssertNil(text("Package.swift", in: target))
        XCTAssertEqual(text(".build/y.o", in: target), "mine")
    }

    /// Given the files git tracks and would track, a mirror copies those alone and removes any other.
    func testAMirrorOfNamedFilesCopiesThoseAlone() throws {
        let (source, target) = (try folder(), try folder())
        try write("tracked", "A.swift", in: source)
        try write("secret", "key.js", in: source)
        try write("old", "key.js", in: target)
        let result = try FolderMirror().mirror(FolderMirrorRequest(sourcePath: source.path, targetPath: target.path, files: ["A.swift"]))

        XCTAssertEqual(result, FolderMirrorResult(copied: 1, removed: 1, unchanged: 0))
        XCTAssertEqual(text("A.swift", in: target), "tracked")
        XCTAssertNil(text("key.js", in: target))
    }
}

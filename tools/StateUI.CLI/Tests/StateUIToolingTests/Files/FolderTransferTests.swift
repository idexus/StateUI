// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

/// A folder carried to another machine's tool and back over one connection - here a service on this machine's
/// loopback, paired as another machine is.
final class FolderTransferTests: XCTestCase {
    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("transfer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    private func write(_ data: Data, _ relative: String, in folder: URL) throws {
        let file = folder.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file)
    }

    private func data(_ relative: String, in folder: URL) -> Data? {
        try? Data(contentsOf: folder.appendingPathComponent(relative))
    }

    /// Runs `body` over a session of a service paired as another machine.
    private func overService<Result: Sendable>(_ body: @Sendable (ServedTool.Session) async throws -> Result) async throws -> Result {
        let state = try folder()
        let pairing = ServicePairing(file: state.appendingPathComponent("clients.json"), name: "Office")
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0, pairing: pairing)
        let serving = Task { await listener.serve() }
        defer { serving.cancel() }
        let machine = try await RemoteMachines(file: state.appendingPathComponent("remotes.json"))
            .pair(name: "office", address: "127.0.0.1", port: listener.port, code: pairing.code)
        return try await ServedTool(remote: machine, workspaceUri: "file:///").session(body)
    }

    /// Sending copies every file, then what changed alone - a file larger than a message in pieces, an empty one too,
    /// each with its time - removes what the source lost, and leaves what a build makes on both sides.
    func testSendingCarriesWhatChangedAndRemovesWhatWent() async throws {
        let (source, target) = (try folder(), try folder())
        let large = Data((0..<(5 << 20)).map { UInt8(truncatingIfNeeded: $0 * 7) })
        try write(large, "Resources/large.bin", in: source)
        try write(Data("one".utf8), "Sources/A.swift", in: source)
        try write(Data(), "Empty.txt", in: source)
        try write(Data("built".utf8), ".build/x.o", in: source)
        try write(Data("mine".utf8), ".build/y.o", in: target)
        try write(Data("old".utf8), "Gone.swift", in: target)
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: time], ofItemAtPath: source.appendingPathComponent("Sources/A.swift").path)

        let first = try await overService { try await FolderTransfer.send(source, files: nil, to: target.path, over: $0, progress: { _ in }) }
        XCTAssertEqual(first, FolderTransfer.Counts(carried: 3, removed: 1, unchanged: 0))
        XCTAssertEqual(data("Resources/large.bin", in: target), large)
        XCTAssertEqual(data("Empty.txt", in: target), Data())
        XCTAssertNil(data("Gone.swift", in: target))
        XCTAssertNil(data(".build/x.o", in: target))
        XCTAssertEqual(data(".build/y.o", in: target), Data("mine".utf8))
        let kept = try target.appendingPathComponent("Sources/A.swift").resourceValues(forKeys: [.contentModificationDateKey])
        XCTAssertEqual(kept.contentModificationDate?.timeIntervalSince1970 ?? 0, time.timeIntervalSince1970, accuracy: 1)

        try write(Data("one more".utf8), "Sources/A.swift", in: source)
        let again = try await overService { try await FolderTransfer.send(source, files: nil, to: target.path, over: $0, progress: { _ in }) }
        XCTAssertEqual(again, FolderTransfer.Counts(carried: 1, removed: 0, unchanged: 2))
        XCTAssertEqual(data("Sources/A.swift", in: target), Data("one more".utf8))
    }

    /// Given the files git tracks and would track, sending carries those alone and removes any other there.
    func testSendingNamedFilesCarriesThoseAlone() async throws {
        let (source, target) = (try folder(), try folder())
        try write(Data("tracked".utf8), "A.swift", in: source)
        try write(Data("secret".utf8), "key.js", in: source)
        try write(Data("old".utf8), "key.js", in: target)
        let counts = try await overService { try await FolderTransfer.send(source, files: ["A.swift"], to: target.path, over: $0, progress: { _ in }) }
        XCTAssertEqual(counts, FolderTransfer.Counts(carried: 1, removed: 1, unchanged: 0))
        XCTAssertNil(data("key.js", in: target))
    }

    /// Fetching brings another machine's folder here - a file larger than a message in pieces - and removes what it
    /// lacks.
    func testFetchingBringsAFolderHome() async throws {
        let (remote, home) = (try folder(), try folder())
        let large = Data((0..<(5 << 20)).map { UInt8(truncatingIfNeeded: $0 * 3) })
        try write(large, "lib/libStateUI.so", in: remote)
        try write(Data("1".utf8), ".stateui-package", in: remote)
        try write(Data("stale".utf8), "Old.dll", in: home)
        let counts = try await overService { try await FolderTransfer.fetch(remote.path, into: home, over: $0, progress: { _ in }) }
        XCTAssertEqual(counts, FolderTransfer.Counts(carried: 2, removed: 1, unchanged: 0))
        XCTAssertEqual(data("lib/libStateUI.so", in: home), large)
        XCTAssertNil(data("Old.dll", in: home))
    }

    /// Every file of a folder is listed, however deep, on every system - a folder a build makes passed over with all it
    /// holds, its siblings and their folders after it still walked.
    func testEveryFileIsListedPastWhatABuildMakes() throws {
        let root = try folder()
        let wanted = [
            ".github/workflows/ci.yml", "A.swift", "apps/Demo/Package.swift", "apps/Demo/Sources/Demo/App.swift",
            "docs/README.md", "lib/StateUI/Core/Sources/View.swift", "lib/StateUI/StateUI.Host/Sources/Host.swift", "tools/x.swift",
        ]
        for path in wanted + [".build/debug/a.o", "apps/Demo/.build/x.o", "lib/StateUI/.swiftpm/y", "lib/.git/HEAD"] {
            try write(Data(path.utf8), path, in: root)
        }
        XCTAssertEqual(try FolderFiles.every(under: root).sorted(), wanted.sorted())
    }

    /// A path names a file inside its folder alone, and a piece follows where the file's last one ended.
    func testAPathStaysInsideItsFolderAndPiecesFollowInOrder() throws {
        let root = try folder()
        for path in ["", "/etc/passwd", "../out", "a/../b", "a/./b", "a//b", #"a\b"#, "C:/x"] {
            XCTAssertThrowsError(try FolderFiles.place(path, in: root), path)
        }
        XCTAssertEqual(try FolderFiles.place("a/b.swift", in: root).path, root.appendingPathComponent("a/b.swift").path)
        _ = try FolderFiles.write(FilesWriteRequest(root: root.path, pieces: [FilePiece(path: "f", offset: 0, size: 4, modified: 0, data: Data("ab".utf8).base64EncodedString())]))
        XCTAssertThrowsError(try FolderFiles.write(FilesWriteRequest(root: root.path, pieces: [FilePiece(path: "f", offset: 3, size: 4, modified: 0, data: Data("d".utf8).base64EncodedString())])))
        XCTAssertNil(data("f", in: root), "a file stands only once whole")
    }
}

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
        let pairing = try ServicePairing(file: state.appendingPathComponent("clients.json"), name: "Office")
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

    /// A file named but gone, or a link, is not carried and its copy there goes; one that cannot be read stops the
    /// transfer, its copy there kept - never taken for a file gone.
    func testAFileThatCannotBeReadStopsTheTransfer() async throws {
        #if os(Windows)
        throw XCTSkip("a link is made on Windows by an administrator or in Developer Mode alone")
        #else
        let (source, target, outside) = (try folder(), try folder(), try folder())
        try write(Data("x".utf8), "L/X.swift", in: outside)
        try FileManager.default.createSymbolicLink(at: source.appendingPathComponent("L"), withDestinationURL: outside.appendingPathComponent("L"))
        try write(Data("kept".utf8), "L/X.swift", in: target)
        try write(Data("gone".utf8), "Gone.swift", in: target)
        do {
            _ = try await overService { try await FolderTransfer.send(source, files: ["L/X.swift", "Gone.swift"], to: target.path, over: $0, progress: { _ in }) }
            XCTFail("a file that cannot be read was taken for one gone")
        } catch {}
        XCTAssertEqual(data("L/X.swift", in: target), Data("kept".utf8))
        _ = try await overService { try await FolderTransfer.send(source, files: ["Gone.swift"], to: target.path, over: $0, progress: { _ in }) }
        XCTAssertNil(data("Gone.swift", in: target), "a file named but gone")
        #endif
    }

    /// A file named that stands in a folder this user may not enter is no file gone: the transfer stops, its copy there
    /// kept.
    func testAFileOutOfReachStopsTheTransfer() async throws {
        #if os(Windows)
        throw XCTSkip("a folder's access is Windows' own lists, not a mode")
        #else
        let (source, target) = (try folder(), try folder())
        try write(Data("secret".utf8), "Private/config.json", in: source)
        try write(Data("kept".utf8), "Private/config.json", in: target)
        let closed = source.appendingPathComponent("Private")
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: closed.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: closed.path) }
        do {
            _ = try await overService { try await FolderTransfer.send(source, files: ["Private/config.json"], to: target.path, over: $0, progress: { _ in }) }
            XCTFail("a file out of reach was taken for one gone")
        } catch {}
        XCTAssertEqual(data("Private/config.json", in: target), Data("kept".utf8))
        #endif
    }

    /// A folder this user may not enter makes no list whole: sending every file, or fetching a folder holding one, stops
    /// - the copies on the other side kept, never removed as files gone.
    func testAFolderOutOfReachMakesNoListWhole() async throws {
        #if os(Windows)
        throw XCTSkip("a folder's access is Windows' own lists, not a mode")
        #else
        let (source, target) = (try folder(), try folder())
        try write(Data("secret".utf8), "Private/config.json", in: source)
        try write(Data("open".utf8), "Open.swift", in: source)
        try write(Data("kept".utf8), "Private/config.json", in: target)
        let closed = source.appendingPathComponent("Private")
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: closed.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: closed.path) }
        do {
            _ = try await overService { try await FolderTransfer.send(source, files: nil, to: target.path, over: $0, progress: { _ in }) }
            XCTFail("a folder out of reach was taken for one gone, sending")
        } catch {}
        XCTAssertEqual(data("Private/config.json", in: target), Data("kept".utf8))
        do {
            _ = try await overService { try await FolderTransfer.fetch(source.path, into: target, over: $0, progress: { _ in }) }
            XCTFail("a folder out of reach was taken for one gone, fetching")
        } catch {}
        XCTAssertEqual(data("Private/config.json", in: target), Data("kept".utf8))
        #endif
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

    #if !os(Windows)
    /// A program stays a program both ways - its executable bit carried, and carried again when it alone changes - and
    /// any other file stays one no one runs.
    func testAProgramStaysAProgramBothWays() async throws {
        let (source, target, home) = (try folder(), try folder(), try folder())
        let executable = { (folder: URL, path: String) in
            FileManager.default.isExecutableFile(atPath: folder.appendingPathComponent(path).path)
        }
        try write(Data("#!/bin/sh\n".utf8), "gradlew", in: source)
        try write(Data("text".utf8), "README.md", in: source)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: source.appendingPathComponent("gradlew").path)

        _ = try await overService { try await FolderTransfer.send(source, files: nil, to: target.path, over: $0, progress: { _ in }) }
        XCTAssertTrue(executable(target, "gradlew"))
        XCTAssertFalse(executable(target, "README.md"))

        _ = try await overService { try await FolderTransfer.fetch(target.path, into: home, over: $0, progress: { _ in }) }
        XCTAssertTrue(executable(home, "gradlew"), "fetched home")
        XCTAssertFalse(executable(home, "README.md"))

        let time = try source.appendingPathComponent("README.md").resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: source.appendingPathComponent("README.md").path)
        try FileManager.default.setAttributes([.modificationDate: time as Any], ofItemAtPath: source.appendingPathComponent("README.md").path)
        let again = try await overService { try await FolderTransfer.send(source, files: nil, to: target.path, over: $0, progress: { _ in }) }
        XCTAssertEqual(again.carried, 1, "its mode alone changed")
        XCTAssertTrue(executable(target, "README.md"))
    }
    #endif

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

    /// A file written again to the same length a second after its copy was carried is carried again - and once
    /// carried, its time kept there, it is the same however long after; a time apart by less than what a file's
    /// time keeps through the connection is the same file.
    func testAChangeOfTheSameLengthIsCarried() {
        let copy = FileEntry(path: "a.swift", size: 9, modified: 1_000_000)
        let edited = FileEntry(path: "a.swift", size: 9, modified: 1_000_001)
        XCTAssertEqual(FolderTransfer.differences([edited], [copy]).changed.map(\.path), ["a.swift"])
        XCTAssertEqual(FolderTransfer.differences([edited], [edited]).changed, [])
        let roundTripped = FileEntry(path: "a.swift", size: 9, modified: 1_000_001.000_000_2)
        XCTAssertEqual(FolderTransfer.differences([edited], [roundTripped]).changed, [])
    }

    /// A path through a link - a folder of the copy linked elsewhere, or a linked file - is refused for writing, reading
    /// and removing alike: what lies past the link stays as it was.
    func testALinkIsNeverPassedThrough() throws {
        #if os(Windows)
        throw XCTSkip("a link is made on Windows by an administrator or in Developer Mode alone")
        #else
        let outside = try folder()
        try write(Data("keep".utf8), "Sources/X.swift", in: outside)
        let root = try folder()
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Sources"), withDestinationURL: outside.appendingPathComponent("Sources"))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Y.swift"), withDestinationURL: outside.appendingPathComponent("Sources/X.swift"))
        let piece = FilePiece(path: "Sources/X.swift", offset: 0, size: 3, modified: 0, data: Data("new".utf8).base64EncodedString())
        XCTAssertThrowsError(try FolderFiles.write(FilesWriteRequest(root: root.path, pieces: [piece])))
        XCTAssertThrowsError(try FolderFiles.remove(FilesRemoveRequest(root: root.path, paths: ["Sources/X.swift"])))
        XCTAssertThrowsError(try FolderFiles.read(FileReadRequest(root: root.path, path: "Sources/X.swift", offset: 0, length: 4)))
        XCTAssertThrowsError(try FolderFiles.read(FileReadRequest(root: root.path, path: "Y.swift", offset: 0, length: 4)))
        // A piece's staging file is written too: one that is a link is refused, never written through.
        try write(Data("keep".utf8), "keep", in: outside)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Z.swift.stateui-part"), withDestinationURL: outside.appendingPathComponent("keep"))
        let staged = FilePiece(path: "Z.swift", offset: 0, size: 3, modified: 0, data: Data("new".utf8).base64EncodedString())
        XCTAssertThrowsError(try FolderFiles.write(FilesWriteRequest(root: root.path, pieces: [staged])))
        XCTAssertEqual(data("keep", in: outside), Data("keep".utf8))
        XCTAssertEqual(data("Sources/X.swift", in: outside), Data("keep".utf8))
        #endif
    }

    /// An offset or a length out of range is a refused request, never the end of the service that read it.
    func testAnOffsetOutOfRangeIsRefused() throws {
        let root = try folder()
        try write(Data("abcd".utf8), "f", in: root)
        XCTAssertThrowsError(try FolderFiles.read(FileReadRequest(root: root.path, path: "f", offset: -1, length: 1)))
        XCTAssertThrowsError(try FolderFiles.read(FileReadRequest(root: root.path, path: "f", offset: 0, length: -1)))
        let piece = FilePiece(path: "g", offset: -1, size: 1, modified: 0, data: Data("a".utf8).base64EncodedString())
        XCTAssertThrowsError(try FolderFiles.write(FilesWriteRequest(root: root.path, pieces: [piece])))
    }
}

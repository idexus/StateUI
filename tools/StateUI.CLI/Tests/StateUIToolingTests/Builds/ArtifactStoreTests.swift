// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ArtifactStoreTests: XCTestCase {
    private func manifest(_ operation: String) -> ArtifactManifest {
        ArtifactManifest(
            schemaVersion: ArtifactManifest.currentVersion, id: "appkit-arm64-0123456789ab-debug", producerOperationId: operation,
            createdAt: "2026-11-13T12:00:00Z", applicationUri: "file:///Apps/Notes", host: .appkit, configuration: .debug,
            architecture: .arm64, productName: "NotesAppKit", entryPoints: ["NotesAppKit.app/Contents/MacOS/NotesAppKit"],
            signing: .adHoc)
    }

    /// An artifact is published whole in place of the last; what a failed operation staged is dropped and the last
    /// published stays as it was.
    func testAnArtifactReplacesTheLastWholeAndAFailureLeavesIt() throws {
        let application = FileManager.default.temporaryDirectory.appendingPathComponent("artifacts-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: application) }
        let store = ArtifactStore(application: application)

        let first = try store.staging(for: "op-1")
        try Data("one".utf8).write(to: first.appendingPathComponent("program"))
        let published = try store.publish(first, as: manifest("op-1"))
        XCTAssertEqual(store.manifest(of: manifest("op-1").id)?.producerOperationId, "op-1")

        let second = try store.staging(for: "op-2")
        try Data("two".utf8).write(to: second.appendingPathComponent("program"))
        _ = try store.publish(second, as: manifest("op-2"))
        XCTAssertEqual(try String(contentsOf: published.appendingPathComponent("program"), encoding: .utf8), "two")
        XCTAssertEqual(store.manifest(of: manifest("op-2").id)?.producerOperationId, "op-2")

        let failed = try store.staging(for: "op-3")
        try Data("half".utf8).write(to: failed.appendingPathComponent("program"))
        store.discard(failed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: failed.path))
        XCTAssertEqual(try String(contentsOf: published.appendingPathComponent("program"), encoding: .utf8), "two")
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: published.deletingLastPathComponent().path), [manifest("op-1").id])
    }
}
